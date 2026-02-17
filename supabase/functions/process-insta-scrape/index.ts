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
    console.log(`\n=== 🚀 INSTA SCRAPE V5: ${handle} ===`)

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

    // 2. SCRAPE
    const cleanHandle = handle.replace('@', '')
    const url = `https://instagram-scraper21.p.rapidapi.com/api/v1/full-posts?username=${cleanHandle}&limit=10`
    const response = await fetch(url, {
      method: 'GET',
      headers: { 'x-rapidapi-key': RAPID_KEY!, 'x-rapidapi-host': 'instagram-scraper21.p.rapidapi.com' }
    });
    const result = await response.json()
    const posts = result.data?.posts || result.posts || []

    // 3. ANALYZE
    const now = new Date()
    const startOfWeek = new Date(now)
    startOfWeek.setDate(now.getDate() - ((now.getDay() + 6) % 7))
    startOfWeek.setHours(0, 0, 0, 0)

    let postsThisWeek = 0
    let totalRawEngagement = 0
    
    posts.forEach((p: any) => {
        const likes = p.like_count || p.likes || 0
        const comments = p.comment_count || p.comments || 0
        totalRawEngagement += (likes + comments)

        if (p.taken_at) {
            const postDate = new Date(p.taken_at * 1000)
            if (postDate >= startOfWeek) postsThisWeek += 1
        }
    })

    // 4. SCORE
    const Ew = posts.length > 0 ? totalRawEngagement / posts.length : 0
    const Hw = Math.min(Math.round((Ew * 0.7) + (1.2 * 0.3) + p_variable), 1000)

    // 5. STREAK & HISTORY
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
      insta_score: Hw,
      insta_post_count: postsThisWeek,
      insta_engagement: totalRawEngagement,
      insta_avg_engagement: Math.round(Ew), // <--- NEW LINE (Insta uses 'Ew' for average)
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