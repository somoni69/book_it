import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { persistSession: false } }
    )

    // Получаем access token для FCM v1
    const accessToken = await getFCMAccessToken()

    const now = new Date()
    const in24Hours = new Date(now.getTime() + 24 * 60 * 60 * 1000)
    const in1Hour = new Date(now.getTime() + 60 * 60 * 1000)

    const bookings24h = await findBookingsForReminder(
      supabase,
      new Date(in24Hours.getTime() - 60 * 60 * 1000),
      new Date(in24Hours.getTime() + 60 * 60 * 1000),
      '24h'
    )

    const bookings1h = await findBookingsForReminder(
      supabase,
      new Date(in1Hour.getTime() - 10 * 60 * 1000),
      new Date(in1Hour.getTime() + 10 * 60 * 1000),
      '1h'
    )

    const allBookings = [...bookings24h, ...bookings1h]
    console.log(`📅 Найдено записей: ${allBookings.length}`)

    const results = await Promise.allSettled(
      allBookings.map(booking => sendReminderV1(supabase, booking, accessToken))
    )

    const sent = results.filter(r => r.status === 'fulfilled' && r.value.success).length
    const failed = results.filter(r => r.status === 'rejected' || (r.status === 'fulfilled' && !r.value.success)).length

    return new Response(
      JSON.stringify({ success: true, processed: allBookings.length, sent, failed, timestamp: now.toISOString() }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ Critical error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// 🔐 Генерация OAuth2 токена через JWT, подписанного RS256 (Web Crypto API)
async function getFCMAccessToken(): Promise<string> {
  const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
  if (!serviceAccountJson) throw new Error('FIREBASE_SERVICE_ACCOUNT not set')

  const sa = JSON.parse(serviceAccountJson)

  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging'
  }

  // Кодируем header и payload в base64url
  const header = { alg: 'RS256', typ: 'JWT' }
  const encodedHeader = base64urlEncode(JSON.stringify(header))
  const encodedPayload = base64urlEncode(JSON.stringify(payload))
  const signingInput = `${encodedHeader}.${encodedPayload}`

  // Импортируем приватный ключ
  const privateKeyPem = sa.private_key
  const privateKey = await importPrivateKey(privateKeyPem)

  // Подписываем
  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    privateKey,
    new TextEncoder().encode(signingInput)
  )

  const encodedSignature = base64urlEncode(signature)
  const jwt = `${signingInput}.${encodedSignature}`

  // Обмениваем JWT на access token
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const data = await response.json()
  if (!response.ok) throw new Error(`OAuth2 error: ${JSON.stringify(data)}`)

  return data.access_token
}

// 🔐 Импорт приватного RSA ключа из PEM
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  // Убираем заголовки и переносы строк
  const pemContents = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')

  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

  return await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )
}

// 🔐 base64url кодирование (без padding)
function base64urlEncode(input: string | ArrayBuffer): string {
  let str: string
  if (typeof input === 'string') {
    str = btoa(input)
  } else {
    const uint8 = new Uint8Array(input)
    str = btoa(String.fromCharCode(...uint8))
  }
  return str.replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}

// 🔍 Поиск записей для напоминания
async function findBookingsForReminder(
  supabase: any,
  startRange: Date,
  endRange: Date,
  reminderType: '24h' | '1h'
): Promise<any[]> {
  const { data: bookings, error } = await supabase
    .from('bookings')
    .select(`
      id,
      client_id,
      master_id,
      start_time,
      status,
      client_profile:profiles!bookings_client_id_fkey(full_name),
      service:services(name),
      fcm_tokens:user_fcm_tokens(fcm_token)
    `)
    .gte('start_time', startRange.toISOString())
    .lt('start_time', endRange.toISOString())
    .in_('status', ['confirmed', 'pending'])
    .order('start_time', { ascending: true })

  if (error) {
    console.error(`❌ Ошибка поиска (${reminderType}):`, error)
    return []
  }

  const result = []
  for (const booking of bookings) {
    const { count } = await supabase
      .from('reminder_logs')
      .select('*', { count: 'exact', head: true })
      .eq('booking_id', booking.id)
      .eq('type', reminderType)

    if (count === 0) {
      result.push({
        ...booking,
        client_name: booking.client_profile?.full_name ?? 'Клиент',
        service_name: booking.service?.name ?? 'Услуга',
        fcm_tokens: booking.fcm_tokens ?? []
      })
    }
  }
  return result
}

// 📤 Отправка уведомления через FCM v1
async function sendReminderV1(
  supabase: any,
  booking: any,
  accessToken: string
): Promise<{ success: boolean }> {
  const reminderType = isWithinOneHour(booking.start_time) ? '1h' : '24h'
  const title = reminderType === '24h' ? 'Напоминание о записи' : 'Скоро ваша запись!'
  const body = reminderType === '24h'
    ? `${booking.client_name}, у вас запись завтра в ${formatTime(booking.start_time)}. Услуга: ${booking.service_name}`
    : `${booking.client_name}, ваша запись через 1 час в ${formatTime(booking.start_time)}`

  const tokens = booking.fcm_tokens.map((t: any) => t.fcm_token).filter(Boolean)
  if (tokens.length === 0) {
    await supabase.from('reminder_logs').insert({
      booking_id: booking.id,
      client_id: booking.client_id,
      type: reminderType,
      status: 'failed',
      error_message: 'Нет FCM токена'
    })
    return { success: false }
  }

  const projectId = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!).project_id
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

  let anySuccess = false
  for (const token of tokens) {
    try {
      const message = {
        message: {
          token,
          notification: { title, body },
          data: {
            booking_id: booking.id,
            screen: 'booking_details',
            type: 'reminder',
            reminder_type: reminderType,
          },
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default', badge: 1 } } },
        },
      }

      const response = await fetch(fcmUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(message),
      })

      const result = await response.json()
      if (response.ok) {
        anySuccess = true
        await supabase.from('reminder_logs').insert({
          booking_id: booking.id,
          client_id: booking.client_id,
          type: reminderType,
          status: 'sent',
          fcm_response: result,
        })
      } else {
        await supabase.from('reminder_logs').insert({
          booking_id: booking.id,
          client_id: booking.client_id,
          type: reminderType,
          status: 'failed',
          error_message: result.error?.message || 'Unknown FCM error',
          fcm_response: result,
        })
      }
    } catch (e: any) {
      await supabase.from('reminder_logs').insert({
        booking_id: booking.id,
        client_id: booking.client_id,
        type: reminderType,
        status: 'failed',
        error_message: e.message,
      })
    }
  }

  return { success: anySuccess }
}

// ⏱ Вспомогательные функции
function isWithinOneHour(startTimeStr: string): boolean {
  const diff = new Date(startTimeStr).getTime() - Date.now()
  const minutes = diff / (1000 * 60)
  return minutes > 50 && minutes < 70
}

function formatTime(dateStr: string): string {
  const d = new Date(dateStr)
  return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`
}