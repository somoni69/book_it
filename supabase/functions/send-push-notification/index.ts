import { serve } from 'https://deno.land/std@0.190.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

console.log('🚀 Функция send-push-notification запущена')

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id, title, body, screen, data } = await req.json()

    console.log('📨 Получен запрос на отправку push:', {
      user_id,
      title,
      body,
      screen,
      data,
      timestamp: new Date().toISOString(),
    })

    // Создаем клиент Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    
    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey)

    // Получаем FCM токен пользователя
    const { data: tokenData, error: tokenError } = await supabaseClient
      .from('user_fcm_tokens')
      .select('fcm_token')
      .eq('user_id', user_id)
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (tokenError) {
      console.error('❌ Ошибка получения токена:', tokenError)
      throw tokenError
    }

    if (!tokenData || !tokenData.fcm_token) {
      console.log('ℹ️ FCM токен не найден для пользователя:', user_id)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'FCM token not found',
          user_id,
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 404,
        }
      )
    }

    const fcmToken = tokenData.fcm_token
    console.log('✅ Найден FCM токен:', fcmToken.substring(0, 20) + '...')

    // Здесь будет реальная отправка через FCM
    // Пока просто логируем
    
    const fcmServerKey = Deno.env.get('FIREBASE_SERVER_KEY')
    
    if (!fcmServerKey) {
      console.log('⚠️ FIREBASE_SERVER_KEY не настроен, пропускаем отправку')
      
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Уведомление зарегистрировано (реальная отправка требует настройки FCM)',
          debug: {
            user_id,
            has_fcm_token: true,
            title,
            body,
          }
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }

    // TODO: Реальная отправка через FCM API
    // const response = await fetch('https://fcm.googleapis.com/fcm/send', {
    //   method: 'POST',
    //   headers: {
    //     'Authorization': `key=${fcmServerKey}`,
    //     'Content-Type': 'application/json',
    //   },
    //   body: JSON.stringify({
    //     to: fcmToken,
    //     notification: { title, body },
    //     data: { screen, ...data },
    //   }),
    // })

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Уведомление отправлено (заглушка)',
        notification: { title, body },
        user_id,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('❌ Ошибка в функции:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message,
        stack: error.stack 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})