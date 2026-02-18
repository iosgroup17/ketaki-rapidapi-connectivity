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
    const RAPID_KEY = Deno.env.get('RAPIDAPI_KEY')
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    const { data: currentData } = await supabase.from('user_analytics').select('*').eq('user_id', user_id).single()

    // 1. Resolve User ID
    const cleanHandle = handle.replace('@', '').trim()
    const profileResp = await fetch(`https://twitter241.p.rapidapi.com/user?username=${cleanHandle}`, {
      headers: { 'x-rapidapi-key': RAPID_KEY!, 'x-rapidapi-host': 'twitter241.p.rapidapi.com' }
    })
    const profileData = await profileResp.json()
    const twitterID = profileData.user?.result?.rest_id || profileData.result?.data?.user?.result?.rest_id
    if (!twitterID) throw new Error("Twitter User Not Found")

    // 2. Get Tweets
    const tweetsResp = await fetch(`https://twitter241.p.rapidapi.com/user-tweets?user=${twitterID}&count=20`, {
      headers: { 'x-rapidapi-key': RAPID_KEY!, 'x-rapidapi-host': 'twitter241.p.rapidapi.com' }
    })
    const tweetsData = await tweetsResp.json()
    const instructions = tweetsData.result?.timeline?.instructions || []
    
    let entries: any[] = []
    instructions.forEach((instr: any) => {
        if (instr.type === "TimelineAddEntries" && instr.entries) entries = entries.concat(instr.entries)
        if (instr.type === "TimelinePinEntry" && instr.entry) entries.push(instr.entry)
    })

    const now = new Date()
    const startOfWeek = new Date(now)
    startOfWeek.setDate(now.getDate() - ((now.getDay() + 6) % 7))
    startOfWeek.setHours(0,0,0,0)
    const nowKey = now.toISOString().split('T')[0]

    let postsThisWeek = 0
    let totalRawEngagement = 0
    let validPostCount = 0
    const dailyMap: Record<string, number> = {}
    
    let bestPost: any = null
    let maxPowerScore = -1

    entries.forEach((entry: any) => {
      if (entry.entryId?.startsWith("promoted") || entry.entryId?.startsWith("who-to-follow")) return
      
      const tweetResult = entry.content?.itemContent?.tweet_results?.result
      const legacy = tweetResult?.legacy || tweetResult?.tweet?.legacy
      
      if (legacy && legacy.created_at) {
          // 🛑 FIX: FILTER OUT RETWEETS
          // If retweeted_status_result exists, it's someone else's post.
          if (legacy.retweeted_status_result || legacy.retweeted_status_id_str) return;

          const postDate = new Date(legacy.created_at)
          
          if (postDate >= startOfWeek) { 
              const likes = legacy.favorite_count || 0
              const reposts = legacy.retweet_count || 0
              const replies = legacy.reply_count || 0
              const views = Number(tweetResult?.views?.count || 0)
              
              // Weekly Stats
              const postEngagement = likes + reposts + replies
              postsThisWeek++
              totalRawEngagement += postEngagement
              validPostCount++

              // Best Post Logic
              const powerScore = likes + (replies * 2) + (reposts * 3)
              if (powerScore > maxPowerScore) {
                  maxPowerScore = powerScore
                  const tweetId = tweetResult?.rest_id || entry.entryId.split('-').pop()
                  bestPost = { 
                      text: legacy.full_text, 
                      likes, 
                      comments: replies, 
                      reposts, 
                      views,
                      date: postDate.toISOString().split('T')[0],
                      url: `https://x.com/${cleanHandle}/status/${tweetId}` 
                  }
              }
              
              // Graph Logic
              const dateKey = postDate.toISOString().split('T')[0]
              if (dateKey === nowKey) {
                  if (!dailyMap[dateKey]) dailyMap[dateKey] = 0
                  dailyMap[dateKey] += postEngagement
              }
          }
      }
  })

    // 3. Upsert Graph Data (Today Only)
    if (dailyMap[nowKey]) {
        await supabase.from('daily_analytics').upsert({ 
            user_id, 
            date: nowKey, 
            platform: 'twitter', 
            engagement: dailyMap[nowKey] 
        }, { onConflict: 'user_id,date,platform' })
    }

    // 4. Upsert Best Post of the Week
    if (bestPost) {
        await supabase.from('best_posts').upsert({
            user_id, 
            platform: 'twitter', 
            post_text: bestPost.text,
            likes: bestPost.likes, 
            comments: bestPost.comments, 
            shares_reposts: bestPost.reposts, 
            extra_metric: bestPost.views,
            post_url: bestPost.url,
            post_date: bestPost.date
        })
    }

    // 5. Calculate Score & Streak
    const avgEng = validPostCount > 0 ? totalRawEngagement / validPostCount : 0
    const Hw = Math.min(Math.round((avgEng * 4.0) + 50 + p_variable), 1000)

    let newStreak = currentData?.consistency_weeks || 0
    let prevScore = currentData?.previous_handle_score || 0
    const lastUpdate = currentData?.last_updated ? new Date(currentData.last_updated) : new Date(0)
    
    if (lastUpdate < startOfWeek) {
        prevScore = currentData?.handle_score || 0
        if (postsThisWeek > 0) newStreak += 1
        else if ((now.getTime() - lastUpdate.getTime()) / 86400000 > 8) newStreak = 0
    } else {
        if (postsThisWeek > 0 && newStreak === 0) newStreak = 1
    }

    // 6. Save Summary Analytics
    await supabase.from('user_analytics').upsert({ 
        user_id, 
        x_score: Hw, 
        x_post_count: postsThisWeek, 
        x_engagement: totalRawEngagement,
        x_avg_engagement: Math.round(avgEng), 
        consistency_weeks: newStreak, 
        previous_handle_score: prevScore, 
        last_updated: now.toISOString()
    }, { onConflict: 'user_id' })

    return new Response(JSON.stringify({ handle_score: Hw, post_count: postsThisWeek }), { 
      headers: { ...corsHeaders, "Content-Type": "application/json" } 
    })

  } catch (err) { 
    return new Response(JSON.stringify({ error: err.message }), { 
      status: 500, 
      headers: corsHeaders 
    }) 
  }
})