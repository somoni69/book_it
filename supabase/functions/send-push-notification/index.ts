import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { booking_id, client_id, title, body, data } = await req.json()

    // Validate required fields
    if (!booking_id || !client_id) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '', 
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    // Get client's FCM token
    const { data: fcmData, error: fcmError } = await supabaseClient
      .from('user_fcm_tokens')
      .select('fcm_token')
      .eq('user_id', client_id)
      .order('updated_at', { ascending: false })
      .limit(1)
      .single()

    if (fcmError || !fcmData) {
      return new Response(
        JSON.stringify({ error: 'FCM token not found', details: fcmError }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const fcmToken = fcmData.fcm_token

    // Send push notification via Firebase
    const firebaseResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${Deno.env.get('FIREBASE_SERVER_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: fcmToken,
        notification: {
          title: title || 'Напоминание о записи',
          body: body || 'У вас скоро запись',
          sound: 'default',
        },
        data: {
          ...data,
          booking_id,
          screen: 'booking_details',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      }),
    })

    const firebaseResult = await firebaseResponse.json()

    // Log the notification in database
    await supabaseClient.from('notification_logs').insert({
      booking_id,
      client_id,
      fcm_token: fcmToken,
      title,
      body,
      sent_at: new Date().toISOString(),
      success: firebaseResult.success === 1,
      response: firebaseResult,
    })

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Notification sent',
        firebase_response: firebaseResult,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
