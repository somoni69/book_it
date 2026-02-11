import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface BookingWithTokens {
  id: string
  client_id: string
  master_id: string
  start_time: string
  client_name: string
  service_name: string
  fcm_tokens: { fcm_token: string }[]
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { persistSession: false } }
    )

    const now = new Date()
    const in24Hours = new Date(now.getTime() + 24 * 60 * 60 * 1000)
    const in1Hour = new Date(now.getTime() + 60 * 60 * 1000)

    // Диапазоны для напоминаний (около ±1 час для гибкости)
    const twentyFourHourStart = new Date(in24Hours.getTime() - 60 * 60 * 1000) // -1 час
    const twentyFourHourEnd = new Date(in24Hours.getTime() + 60 * 60 * 1000)   // +1 час

    const oneHourStart = new Date(in1Hour.getTime() - 10 * 60 * 1000)          // -10 минут
    const oneHourEnd = new Date(in1Hour.getTime() + 10 * 60 * 1000)            // +10 минут

    // Ищем записи для напоминания за 24 часа
    const bookings24h = await findBookingsForReminder(supabase, twentyFourHourStart, twentyFourHourEnd, '24h')
    // Ищем записи для напоминания за 1 час
    const bookings1h = await findBookingsForReminder(supabase, oneHourStart, oneHourEnd, '1h')

    const allBookings = [...bookings24h, ...bookings1h]

    console.log(`Найдено записей для обработки: ${allBookings.length}`)

    // Отправляем уведомления
    const results = await Promise.allSettled(
      allBookings.map(booking => sendReminder(supabase, booking))
    )

    const sent = results.filter(r => r.status === 'fulfilled' && r.value.success).length
    const failed = results.filter(r => r.status === 'rejected' || (r.status === 'fulfilled' && !r.value.success)).length

    return new Response(
      JSON.stringify({
        success: true,
        processed: allBookings.length,
        sent,
        failed,
        timestamp: now.toISOString(),
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Critical error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

async function findBookingsForReminder(
  supabase: any,
  startRange: Date,
  endRange: Date,
  reminderType: '24h' | '1h'
): Promise<BookingWithTokens[]> {
  // 1. Получаем записи, попадающие в диапазон
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
      fcm_tokens:user_fcm_tokens!inner(fcm_token)
    `)
    .gte('start_time', startRange.toISOString())
    .lt('start_time', endRange.toISOString())
    .in('status', ['confirmed', 'pending'])
    .neq('client_id', supabase.auth.user()?.id)
    .order('start_time', { ascending: true })

  if (error) {
    console.error(`Ошибка поиска записей (${reminderType}):`, error)
    return []
  }

  // 2. Фильтруем те, по которым ещё не отправлялось напоминание данного типа
  const bookingsWithNoReminder = []
  for (const booking of bookings) {
    const { count, error: logError } = await supabase
      .from('reminder_logs')
      .select('*', { count: 'exact', head: true })
      .eq('booking_id', booking.id)
      .eq('type', reminderType)

    if (logError) {
      console.error(`Ошибка проверки логов для booking ${booking.id}:`, logError)
      continue
    }

    if (count === 0) {
      bookingsWithNoReminder.push({
        ...booking,
        client_name: booking.client_profile?.full_name ?? 'Клиент',
        service_name: booking.service?.name ?? 'Услуга',
        fcm_tokens: booking.fcm_tokens ?? []
      })
    }
  }

  return bookingsWithNoReminder
}

async function sendReminder(supabase: any, booking: BookingWithTokens) {
  const reminderType = isWithinOneHour(booking.start_time) ? '1h' : '24h'
  const title = reminderType === '24h'
    ? 'Напоминание о записи'
    : 'Скоро ваша запись!'
  const body = reminderType === '24h'
    ? `${booking.client_name}, у вас запись завтра в ${formatTime(booking.start_time)}. Услуга: ${booking.service_name}`
    : `${booking.client_name}, ваша запись через 1 час в ${formatTime(booking.start_time)}`

  const fcmTokens = booking.fcm_tokens.map(t => t.fcm_token).filter(Boolean)

  if (fcmTokens.length === 0) {
    // Логируем, что не удалось отправить из-за отсутствия токена
    await supabase.from('reminder_logs').insert({
      booking_id: booking.id,
      client_id: booking.client_id,
      type: reminderType,
      status: 'failed',
      error_message: 'No FCM tokens found'
    })
    return { success: false, reason: 'no_token' }
  }

  let anySuccess = false
  for (const token of fcmTokens) {
    try {
      const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Authorization': `key=${Deno.env.get('FIREBASE_SERVER_KEY')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: token,
          notification: {
            title,
            body,
            sound: 'default',
          },
          data: {
            booking_id: booking.id,
            screen: 'booking_details',
            type: 'reminder',
            reminder_type: reminderType,
          },
          android: { priority: 'high' },
          apns: { payload: { aps: { sound: 'default', badge: 1 } } },
        }),
      })

      const result = await fcmResponse.json()

      if (result.success === 1) {
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
          error_message: result.results?.[0]?.error || 'Unknown FCM error',
          fcm_response: result,
        })
      }
    } catch (error) {
      await supabase.from('reminder_logs').insert({
        booking_id: booking.id,
        client_id: booking.client_id,
        type: reminderType,
        status: 'failed',
        error_message: error.message,
      })
    }
  }

  return { success: anySuccess }
}

function isWithinOneHour(startTimeStr: string): boolean {
  const start = new Date(startTimeStr)
  const now = new Date()
  const diffMs = start.getTime() - now.getTime()
  const diffMinutes = diffMs / (1000 * 60)
  return diffMinutes > 50 && diffMinutes < 70 // грубое определение
}

function formatTime(dateStr: string): string {
  const d = new Date(dateStr)
  return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`
}
