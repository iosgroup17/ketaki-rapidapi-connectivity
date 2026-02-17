import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { handle, user_id, p_variable = 0 } = await req.json()
    console.log(`\n=== 👔 LINKEDIN SCRAPE V5: ${handle} ===`)

    const RAPID_KEY = Deno.env.get('RAPIDAPI_KEY')
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    // 1. FETCH STATE
    const { data: currentData } = await supabase
        .from('user_analytics')
        .select('consistency_weeks, last_updated, handle_score, previous_handle_score')
        .eq('user_id', user_id)
        .single()

    // 2. FETCH DATA
    const cleanHandle = handle.replace('@', '').split('/').filter(Boolean).pop()
    const postsUrl = `https://fresh-linkedin-scraper-api.p.rapidapi.com/api/v1/user/posts?username=${cleanHandle}`
    const response = await fetch(postsUrl, {
      method: 'GET',
      headers: { 'x-rapidapi-key': RAPID_KEY!, 'x-rapidapi-host': 'fresh-linkedin-scraper-api.p.rapidapi.com' }
    })
    const result = await response.json()
    const posts = result.data || []

    // 3. ANALYZE
    const now = new Date()
    const startOfWeek = new Date(now)
    startOfWeek.setDate(now.getDate() - ((now.getDay() + 6) % 7)) 
    startOfWeek.setHours(0, 0, 0, 0)

    let postsThisWeek = 0
    let totalRawEngagement = 0

    posts.forEach((p: any) => {
        const act = p.activity || {}
        const social = p.social_counts || {}
        const likes = act.num_likes || p.num_likes || social.num_likes || 0
        const comments = act.num_comments || p.num_comments || social.num_comments || 0
        totalRawEngagement += (Number(likes) + Number(comments))

        let isRecent = false
        if (p.created_at) {
             if (new Date(p.created_at) >= startOfWeek) isRecent = true
        } else if (p.postedAtTimestamp) {
            if (new Date(p.postedAtTimestamp * 1000) >= startOfWeek) isRecent = true
        }
        if (isRecent) postsThisWeek++
    })

    // 4. SCORE
    const avgEng = posts.length > 0 ? totalRawEngagement / posts.length : 0
    const Hw = Math.min(Math.round((avgEng * 3.0) + 100 + p_variable), 1000)

    // 5. STREAK & HISTORY UPDATE
    let newStreak = currentData?.consistency_weeks || 0
    let prevScore = currentData?.previous_handle_score || 0
    const lastUpdate = currentData?.last_updated ? new Date(currentData.last_updated) : new Date(0)
    const isNewWeek = lastUpdate < startOfWeek

    if (isNewWeek) {
        prevScore = currentData?.handle_score || 0
        if (postsThisWeek > 0) newStreak += 1
        else {
            const daysSince = (now.getTime() - lastUpdate.getTime()) / (1000 * 3600 * 24)
            if (daysSince > 8) newStreak = 0
        }
    } else {
        if (postsThisWeek > 0 && newStreak === 0) newStreak = 1
    }

    // 6. SAVE
    // ... inside the upsert function ...
    const { error: dbError } = await supabase.from('user_analytics').upsert({ 
      user_id: user_id, 
      linkedin_score: Hw,
      linkedin_post_count: postsThisWeek,
      linkedin_engagement: totalRawEngagement,
      linkedin_avg_engagement: Math.round(avgEng), // <--- NEW LINE
      consistency_weeks: newStreak,
      previous_handle_score: prevScore,
      last_updated: now.toISOString()
  }, { onConflict: 'user_id' })

    if (dbError) throw dbError

    return new Response(JSON.stringify({ handle_score: Hw, post_count: postsThisWeek }), { 
      headers: { ...corsHeaders, "Content-Type": "application/json" } 
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders })
  }
})