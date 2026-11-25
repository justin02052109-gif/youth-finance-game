BEGIN;
CREATE OR REPLACE FUNCTION public.life_goals(p_room_id uuid,p_goals jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.rooms%ROWTYPE; pid uuid; allowed jsonb; old_goals jsonb;
BEGIN
 SELECT * INTO r FROM public.rooms WHERE id=p_room_id FOR UPDATE;
 IF NOT FOUND OR auth.uid() IS NULL OR r.status NOT IN ('waiting','playing') THEN RAISE EXCEPTION '目前不能設定目標'; END IF;
 SELECT id INTO pid FROM public.players WHERE room_id=r.id AND user_id=auth.uid();
 IF NOT FOUND THEN RAISE EXCEPTION '僅限房間玩家'; END IF;
 SELECT extra_state->'goals' INTO old_goals FROM public.player_states WHERE player_id=pid FOR UPDATE;
 IF old_goals IS NOT NULL AND r.status='playing' AND r.settled_round>0 THEN RAISE EXCEPTION '目標已鎖定'; END IF;
 SELECT rules->'goals' INTO STRICT allowed FROM public.life_rules WHERE version=r.rules_version;
 IF p_goals IS NULL OR jsonb_typeof(p_goals)<>'array' THEN RAISE EXCEPTION '請選擇2至3項目標'; END IF;
 IF jsonb_array_length(p_goals) NOT BETWEEN 2 AND 3 OR NOT (allowed @> p_goals) OR (SELECT count(DISTINCT value) FROM jsonb_array_elements(p_goals))<>jsonb_array_length(p_goals) THEN RAISE EXCEPTION '請選擇2至3項不同的有效目標'; END IF;
 UPDATE public.player_states SET extra_state=jsonb_set(extra_state,'{goals}',p_goals,true),updated_at=now() WHERE player_id=pid;
END; $$;
CREATE OR REPLACE FUNCTION public.life_repay(p_room_id uuid,p_round integer,p_amount bigint,p_expected_cash bigint,p_expected_debt bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.rooms%ROWTYPE; s public.player_states%ROWTYPE; pid uuid;
BEGIN
 SELECT * INTO r FROM public.rooms WHERE id=p_room_id FOR UPDATE;
 IF NOT FOUND OR auth.uid() IS NULL OR r.status<>'playing' OR r.round_phase<>'result' OR r.settled_round IS DISTINCT FROM p_round THEN RAISE EXCEPTION '只可在年度結算後、下一年開始前還款'; END IF;
 SELECT id INTO pid FROM public.players WHERE room_id=r.id AND user_id=auth.uid();
 IF NOT FOUND THEN RAISE EXCEPTION '僅限房間玩家'; END IF;
 SELECT * INTO STRICT s FROM public.player_states WHERE player_id=pid FOR UPDATE;
 IF s.cash IS DISTINCT FROM p_expected_cash OR s.debt IS DISTINCT FROM p_expected_debt THEN RAISE EXCEPTION '金額已更新，請重新確認'; END IF;
 IF p_amount IS NULL OR p_amount<=0 OR p_amount>least(s.cash,s.debt) THEN RAISE EXCEPTION '還款金額超過存款或負債'; END IF;
 UPDATE public.player_states SET cash=s.cash-p_amount,debt=s.debt-p_amount,updated_at=now() WHERE player_id=pid;
 UPDATE public.round_results SET ending_cash=s.cash-p_amount,ending_debt=s.debt-p_amount,result_data=jsonb_set(result_data,'{repaid}',to_jsonb(coalesce((result_data->>'repaid')::numeric,0)+p_amount::numeric/10000),true) WHERE player_id=pid AND round_number=p_round;
 IF NOT FOUND THEN RAISE EXCEPTION '找不到年度結算紀錄'; END IF;
END; $$;
CREATE OR REPLACE FUNCTION public.life_profile(p_room_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.rooms%ROWTYPE; pid uuid; s public.player_states%ROWTYPE; allowed jsonb;
BEGIN
 SELECT * INTO r FROM public.rooms WHERE id=p_room_id;
 IF NOT FOUND OR auth.uid() IS NULL THEN RAISE EXCEPTION '無法存取房間'; END IF;
 SELECT id INTO pid FROM public.players WHERE room_id=r.id AND user_id=auth.uid();
 IF NOT FOUND THEN RAISE EXCEPTION '僅限房間玩家'; END IF;
 SELECT * INTO STRICT s FROM public.player_states WHERE player_id=pid;
 SELECT rules->'goals' INTO STRICT allowed FROM public.life_rules WHERE version=r.rules_version;
 RETURN jsonb_build_object('state',s.extra_state,'goals_catalog',allowed,'cash',s.cash,'debt',s.debt,'age',s.age,'free_days',s.free_days,'round',r.current_round,'phase',r.round_phase,'status',r.status,'goals_locked',r.status='finished' OR (r.status='playing' AND r.settled_round>0 AND s.extra_state?'goals'));
END; $$;
REVOKE ALL ON FUNCTION public.life_goals(uuid,jsonb),public.life_repay(uuid,integer,bigint,bigint,bigint),public.life_profile(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.life_goals(uuid,jsonb),public.life_repay(uuid,integer,bigint,bigint,bigint),public.life_profile(uuid) TO authenticated;
COMMIT;
