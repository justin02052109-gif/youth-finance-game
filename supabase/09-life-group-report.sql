BEGIN;
CREATE OR REPLACE FUNCTION public.life_group_report(p_room_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.rooms%ROWTYPE; report jsonb;
BEGIN
 SELECT * INTO r FROM public.rooms WHERE id=p_room_id FOR SHARE;
 IF NOT FOUND OR auth.uid() IS NULL OR r.host_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION '僅限主持人查看團體成果'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
 'nickname',p.nickname,'cash',s.cash,'debt',s.debt,'age',s.age,'state',s.extra_state,'free_days',s.free_days,
 'history',coalesce((SELECT jsonb_agg(jsonb_build_object('round',x.round_number,'age',x.age,'income',x.income,'expenses',x.expenses,'cash',x.ending_cash,'debt',x.ending_debt,'category',x.result_data->>'category','action',x.result_data->>'actual','activity',x.result_data->>'activity','free_days',x.result_data->'free_days','used_days',x.result_data->'used_days','loan',x.result_data->'loan','repaid',x.result_data->'repaid','education_cost',x.result_data->'education_cost','activity_cost',x.result_data->'activity_cost','fallback_used',x.result_data->'fallback_used') ORDER BY x.round_number) FROM public.round_results x WHERE x.player_id=p.id AND x.round_number<=r.settled_round),'[]'::jsonb)
 ) ORDER BY p.joined_at,p.id),'[]'::jsonb) INTO report
 FROM public.players p JOIN public.player_states s ON s.player_id=p.id WHERE p.room_id=r.id;
 RETURN jsonb_build_object('settled',r.settled_round,'status',r.status,'players',report);
END; $$;
REVOKE ALL ON FUNCTION public.life_group_report(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.life_group_report(uuid) TO authenticated;
COMMIT;
