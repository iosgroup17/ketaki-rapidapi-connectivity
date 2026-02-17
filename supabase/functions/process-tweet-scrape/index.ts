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
    console.log(`\n=== 🐦 TWITTER SCRAPE V5: ${handle} ===`)

    const RAPID_KEY = Deno.env.get('RAPIDAPI_KEY')
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    // 1. FETCH CURRENT DB STATE
    const { data: currentData } = await supabase
        .from('user_analytics')
        .select('consistency_weeks, last_updated, handle_score, previous_handle_score')
        .eq('user_id', user_id)
        .single()

    // 2. GET USER ID
    const cleanHandle = handle.replace('@', '').trim()
    const profileUrl = `https://twitter241.p.rapidapi.com/user?username=${cleanHandle}`
    const profileResp = await fetch(profileUrl, {
      method: 'GET',
      headers: { 'x-rapidapi-key': RAPID_KEY!, 'x-rapidapi-host': 'twitter241.p.rapidapi.com' }
    })
    const profileData = await profileResp.json()
    const twitterID = profileData.result?.data?.user?.result?.rest_id || 
                      profileData.user?.result?.rest_id || 
                      profileData.data?.user?.result?.rest_id

    if (!twitterID) throw new Error("Twitter User Not Found")

    // 3. GET TWEETS
    const tweetsUrl = `https://twitter241.p.rapidapi.com/user-tweets?user=${twitterID}&count=20`
    const tweetsResp = await fetch(tweetsUrl, {
      method: 'GET',
      headers: { 'x-rapidapi-key': RAPID_KEY!, 'x-rapidapi-host': 'twitter241.p.rapidapi.com' }
    })
    const tweetsData = await tweetsResp.json()
    
    // Parse Timeline
    const instructions = tweetsData.result?.timeline?.instructions || 
                         tweetsData.data?.user?.result?.timeline?.timeline?.instructions || []
    let entries: any[] = []
    instructions.forEach((instr: any) => {
        if (instr.type === "TimelineAddEntries" && instr.entries) entries = entries.concat(instr.entries)
        if (instr.type === "TimelinePinEntry" && instr.entry) entries.push(instr.entry)
    })

    // 4. ANALYZE
    const now = new Date()
    const startOfWeek = new Date(now)
    startOfWeek.setDate(now.getDate() - ((now.getDay() + 6) % 7)) // Monday 00:00
    startOfWeek.setHours(0,0,0,0)

    let postsThisWeek = 0
    let totalRawEngagement = 0
    let validPostCount = 0

    entries.forEach((entry: any) => {
        if (entry.entryId?.startsWith("promoted") || entry.entryId?.startsWith("who-to-follow")) return
        const legacy = entry.content?.itemContent?.tweet_results?.result?.legacy
        if (legacy) {
            const eng = (legacy.favorite_count || 0) + (legacy.retweet_count || 0) + (legacy.reply_count || 0) + (legacy.quote_count || 0)
            totalRawEngagement += eng
            validPostCount++
            if (legacy.created_at && new Date(legacy.created_at) >= startOfWeek) postsThisWeek++
        }
    })

    // 5. SCORE
    const avgEng = validPostCount > 0 ? totalRawEngagement / validPostCount : 0
    const Hw = Math.min(Math.round((avgEng * 4.0) + 50 + p_variable), 1000)

    // 6. STREAK & HISTORY UPDATE (Shared Logic)
    let newStreak = currentData?.consistency_weeks || 0
    let prevScore = currentData?.previous_handle_score || 0
    const lastUpdate = currentData?.last_updated ? new Date(currentData.last_updated) : new Date(0)
    const isNewWeek = lastUpdate < startOfWeek

    if (isNewWeek) {
        // Snapshot the old score
        prevScore = currentData?.handle_score || 0
        
        if (postsThisWeek > 0) {
            newStreak += 1
        } else {
            // Only reset streak if user has been inactive for > 8 days across ALL platforms
            const daysSince = (now.getTime() - lastUpdate.getTime()) / (1000 * 3600 * 24)
            if (daysSince > 8) newStreak = 0
        }
    } else {
        // Same week: If we found posts now but streak was 0, fix it
        if (postsThisWeek > 0 && newStreak === 0) newStreak = 1
    }

    // 7. SAVE
    // ... inside the upsert function ...
    const { error: dbError } = await supabase.from('user_analytics').upsert({ 
      user_id: user_id, 
      x_score: Hw,
      x_post_count: postsThisWeek,
      x_engagement: totalRawEngagement,
      x_avg_engagement: Math.round(avgEng), // <--- NEW LINE
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