BEGIN;
CREATE OR REPLACE FUNCTION public.life_activities()
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$
SELECT '[{"id":"none","name":"不另外安排","cost":0,"days":0},{"id":"domestic","name":"國內旅遊","cost":1.5,"days":3},{"id":"foreign","name":"國外旅遊","cost":5,"days":7},{"id":"family","name":"家庭陪伴","cost":0,"days":2},{"id":"hobby","name":"興趣課程","cost":1,"days":5},{"id":"study","name":"短期進修","cost":1.5,"days":10},{"id":"volunteer","name":"志願服務","cost":0,"days":3}]'::jsonb;
$$;
CREATE OR REPLACE FUNCTION public.life_turn(p_room_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.rooms%ROWTYPE; p public.players%ROWTYPE; s public.player_states%ROWTYPE; d jsonb;
BEGIN
 SELECT * INTO r FROM public.rooms WHERE id=p_room_id;
 IF NOT FOUND OR auth.uid() IS NULL OR r.status<>'playing' THEN RAISE EXCEPTION '遊戲尚未開始或已結束'; END IF;
 IF r.host_id=auth.uid() THEN
  RETURN jsonb_build_object('host',true,'round',r.current_round,'phase',r.round_phase,'players',coalesce((SELECT jsonb_agg(jsonb_build_object('nickname',x.nickname,'submitted',EXISTS(SELECT 1 FROM public.decisions y WHERE y.player_id=x.id AND y.round_number=r.current_round)) ORDER BY x.joined_at) FROM public.players x WHERE x.room_id=r.id),'[]'::jsonb));
 END IF;
 SELECT * INTO p FROM public.players WHERE room_id=r.id AND user_id=auth.uid();
 IF NOT FOUND THEN RAISE EXCEPTION '你尚未加入房間'; END IF;
 SELECT * INTO STRICT s FROM public.player_states WHERE player_id=p.id;
 SELECT jsonb_build_object('main',main_choice,'activity',experience_choice,'data',decision_data) INTO d FROM public.decisions WHERE player_id=p.id AND round_number=r.current_round;
 RETURN jsonb_build_object('host',false,'round',r.current_round,'phase',r.round_phase,'age',s.age,'cash',s.cash,'debt',s.debt,'education',s.education,'skills',s.skills,'work_experience',s.work_experience,'free_days',s.free_days,'state',s.extra_state,'options',public.life_options(s.extra_state,r.current_round,r.rules_version),'activities',public.life_activities(),'decision',d);
END; $$;

CREATE OR REPLACE FUNCTION public.life_submit(p_room_id uuid,p_round integer,p_main text,p_activity text,p_fallback text,p_accept_debt boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.rooms%ROWTYPE; p public.players%ROWTYPE; s public.player_states%ROWTYPE; opts jsonb; o jsonb; f jsonb; a jsonb; v_cash numeric;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION '請先登入'; END IF;
 SELECT * INTO r FROM public.rooms WHERE id=p_room_id FOR UPDATE;
 IF NOT FOUND OR r.status<>'playing' OR r.round_phase<>'decision' OR r.current_round IS DISTINCT FROM p_round THEN RAISE EXCEPTION '目前無法提交此年度'; END IF;
 SELECT * INTO p FROM public.players WHERE room_id=r.id AND user_id=auth.uid();
 IF NOT FOUND THEN RAISE EXCEPTION '你尚未加入房間'; END IF;
 SELECT * INTO STRICT s FROM public.player_states WHERE player_id=p.id;
 opts:=public.life_options(s.extra_state,r.current_round,r.rules_version);
 SELECT value INTO o FROM jsonb_array_elements(opts) WHERE value->>'id'=p_main AND (value->>'ok')::boolean;
 IF NOT FOUND THEN RAISE EXCEPTION '不符合年度行動資格'; END IF;
 SELECT value INTO a FROM jsonb_array_elements(public.life_activities()) WHERE value->>'id'=p_activity;
 IF NOT FOUND THEN RAISE EXCEPTION '無效人生體驗'; END IF;
 v_cash:=s.cash::numeric/10000;
 IF (a->>'days')::int>(o->>'free')::int OR (a->>'cost')::numeric>greatest(0,v_cash+(o->>'net')::numeric) THEN RAISE EXCEPTION '人生體驗時間或資金不足'; END IF;
 IF v_cash+(o->>'net')::numeric<0 AND p_accept_debt IS DISTINCT FROM true THEN RAISE EXCEPTION '需要同意模擬借款'; END IF;
 IF o->>'cat'='特殊職缺' THEN
  SELECT value INTO f FROM jsonb_array_elements(opts) WHERE value->>'id'=p_fallback AND value->>'cat'<>'特殊職缺' AND (value->>'ok')::boolean;
  IF NOT FOUND THEN RAISE EXCEPTION '請選擇符合資格的非特殊職缺備案'; END IF;
  IF (a->>'days')::int>(f->>'free')::int OR (a->>'cost')::numeric>greatest(0,v_cash+(f->>'net')::numeric) THEN RAISE EXCEPTION '人生體驗也須符合備案時間與資金'; END IF;
  IF v_cash+(f->>'net')::numeric<0 AND p_accept_debt IS DISTINCT FROM true THEN RAISE EXCEPTION '備案需要同意模擬借款'; END IF;
 ELSE p_fallback:=NULL; END IF;
 INSERT INTO public.decisions(player_id,round_number,main_choice,experience_choice,decision_data)
 VALUES(p.id,p_round,p_main,p_activity,jsonb_build_object('fallback',p_fallback,'accept_debt',coalesce(p_accept_debt,false)))
 ON CONFLICT(player_id,round_number) DO UPDATE SET main_choice=excluded.main_choice,experience_choice=excluded.experience_choice,decision_data=excluded.decision_data,submitted_at=now();
END; $$;
REVOKE ALL ON FUNCTION public.life_activities() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.life_turn(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.life_submit(uuid,integer,text,text,text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.life_turn(uuid), public.life_submit(uuid,integer,text,text,text,boolean) TO authenticated;
COMMIT;
