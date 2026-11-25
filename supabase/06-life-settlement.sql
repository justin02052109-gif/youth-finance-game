BEGIN;
CREATE OR REPLACE FUNCTION public.life_settle(p_room_id uuid,p_round integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
#variable_conflict use_variable
DECLARE r public.rooms%ROWTYPE; p record; s public.player_states%ROWTYPE; o jsonb; a jsonb; opts jsonb; st jsonb; winners jsonb; chosen text; n numeric; loan numeric; cash_end numeric; debt_end numeric; study jsonb; skills jsonb; exp jsonb; experiences jsonb; degree integer; k text; progress numeric; event_text text;
BEGIN
 SELECT * INTO r FROM public.rooms WHERE id=p_room_id FOR UPDATE;
 IF NOT FOUND OR auth.uid() IS NULL OR r.host_id<>auth.uid() THEN RAISE EXCEPTION '僅限主持人結算'; END IF;
 IF r.status<>'playing' OR r.current_round IS DISTINCT FROM p_round OR r.round_phase<>'decision' OR r.settled_round>=p_round THEN RAISE EXCEPTION '此回合不可重複結算'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.players WHERE room_id=r.id) OR EXISTS(SELECT 1 FROM public.players x WHERE x.room_id=r.id AND NOT EXISTS(SELECT 1 FROM public.decisions d WHERE d.player_id=x.id AND d.round_number=p_round)) THEN RAISE EXCEPTION '尚有玩家未提交'; END IF;
 -- Each eligible special vacancy has one winner, drawn once per transaction.
 SELECT coalesce(jsonb_object_agg(z.main_choice,z.player_id),'{}'::jsonb) INTO winners FROM (
 SELECT DISTINCT ON(d.main_choice) d.main_choice,d.player_id
 FROM public.decisions d JOIN public.players x ON x.id=d.player_id
 JOIN public.player_states ps ON ps.player_id=x.id
 CROSS JOIN LATERAL jsonb_array_elements(public.life_options(ps.extra_state,p_round,r.rules_version)) opt(v)
 WHERE x.room_id=r.id AND d.round_number=p_round AND opt.v->>'id'=d.main_choice AND opt.v->>'cat'='特殊職缺' AND (opt.v->>'ok')::boolean
 ORDER BY d.main_choice,random()
 ) z;
 FOR p IN SELECT x.id,d.main_choice,d.experience_choice,d.decision_data FROM public.players x JOIN public.decisions d ON d.player_id=x.id AND d.round_number=p_round WHERE x.room_id=r.id ORDER BY x.id LOOP
  SELECT * INTO STRICT s FROM public.player_states WHERE player_id=p.id FOR UPDATE;
  opts:=public.life_options(s.extra_state,p_round,r.rules_version);
  chosen:=p.main_choice;
  SELECT value INTO STRICT o FROM jsonb_array_elements(opts) WHERE value->>'id'=chosen AND (value->>'ok')::boolean;
  IF o->>'cat'='特殊職缺' AND (winners->>chosen) IS DISTINCT FROM p.id::text THEN
   chosen:=p.decision_data->>'fallback';
   SELECT value INTO STRICT o FROM jsonb_array_elements(opts) WHERE value->>'id'=chosen AND value->>'cat'<>'特殊職缺' AND (value->>'ok')::boolean;
  END IF;
  SELECT value INTO STRICT a FROM jsonb_array_elements(public.life_activities()) WHERE value->>'id'=p.experience_choice;
  n:=s.cash::numeric/10000+(o->>'net')::numeric;
  loan:=greatest(0,-n);
  IF loan>0 AND (p.decision_data->>'accept_debt')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION '借款尚未同意'; END IF;
  IF (a->>'days')::int>(o->>'free')::int OR (a->>'cost')::numeric>greatest(0,n) THEN RAISE EXCEPTION '體驗資格不符'; END IF;
  cash_end:=n+loan-(a->>'cost')::numeric; debt_end:=s.debt::numeric/10000+loan;
  st:=s.extra_state; study:=coalesce(st->'study','{}'::jsonb); skills:=coalesce(st->'skills','[]'::jsonb); exp:=coalesce(st->'exp','{}'::jsonb); experiences:=coalesce(st->'experiences','[]'::jsonb); degree:=coalesce((st->>'degree')::int,0);
  IF o ? 'study' THEN
   k:=o->>'study'; progress:=least((o->>'len')::numeric,coalesce((study->>k)::numeric,0)+(o->>'inc')::numeric);
   study:=jsonb_set(study,ARRAY[k],to_jsonb(progress),true);
   IF progress>=(o->>'len')::numeric THEN degree:=greatest(degree,(o->>'degree')::int); IF k='tech' AND NOT(skills?'應用技術') THEN skills:=skills||jsonb_build_array('應用技術'); END IF; END IF;
  END IF;
  IF o ? 'skill' AND NOT(skills?(o->>'skill')) THEN skills:=skills||jsonb_build_array(o->>'skill'); END IF;
  IF o ? 'industry' THEN k:=o->>'industry'; exp:=jsonb_set(exp,ARRAY[k],to_jsonb(coalesce((exp->>k)::numeric,0)+(o->>'exp')::numeric),true); END IF;
  IF a->>'id'<>'none' THEN experiences:=experiences||jsonb_build_array(a->>'name'); END IF;
  IF o ? 'experience' THEN experiences:=experiences||jsonb_build_array(o->>'experience'); END IF;
  st:=st||jsonb_build_object('degree',degree,'study',study,'skills',skills,'exp',exp,'experiences',experiences,'current',o->>'name');
  UPDATE public.player_states SET age=18+p_round,cash=round(cash_end*10000)::bigint,debt=round(debt_end*10000)::bigint,education=(ARRAY['high_school','college','university','master'])[degree+1],skills=skills,work_experience=exp,life_experiences=experiences,free_days=s.free_days+(o->>'free')::int,extra_state=st,updated_at=now() WHERE player_id=p.id;
  INSERT INTO public.round_results(player_id,round_number,age,income,expenses,ending_cash,ending_debt,result_data)
  VALUES(p.id,p_round,17+p_round,round((o->>'salary')::numeric*10000)::bigint,round(((o->>'salary')::numeric-(o->>'net')::numeric+(a->>'cost')::numeric)*10000)::bigint,round(cash_end*10000)::bigint,round(debt_end*10000)::bigint,jsonb_build_object('requested',p.main_choice,'actual',o->>'name','fallback_used',chosen<>p.main_choice,'category',o->>'cat','activity',a->>'name','loan',loan,'education_cost',o->'fee','free_days',o->'free','used_days',a->'days','activity_cost',a->'cost','net',(o->>'net')::numeric-(a->>'cost')::numeric,'before',s.extra_state,'after',st));
 END LOOP;
 event_text:=CASE p_round WHEN 3 THEN '教育及職訓資源增加：下一年度升學補助3萬元、職訓費用減半。' WHEN 6 THEN '新興產業發展：下一年度資訊及水電職缺年薪增加6萬元。' WHEN 9 THEN '產業轉型：下一年度設計、行政職缺年薪增加3萬元。' WHEN 12 THEN '在職進修資源增加：下一年度升學補助3萬元、職訓費用減半。' WHEN 15 THEN '服務與技術需求增加：下一年度行政、水電及照顧職缺年薪增加6萬元。' ELSE NULL END;
 IF event_text IS NOT NULL THEN INSERT INTO public.game_events(room_id,round_number,event_type,title,description) VALUES(r.id,p_round,'common','共同事件',event_text); END IF;
 UPDATE public.rooms SET settled_round=p_round,round_phase='result' WHERE id=r.id;
END; $$;
CREATE OR REPLACE FUNCTION public.life_next(p_room_id uuid,p_round integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.rooms%ROWTYPE;
BEGIN
 SELECT * INTO r FROM public.rooms WHERE id=p_room_id FOR UPDATE;
 IF NOT FOUND OR auth.uid() IS NULL OR r.host_id<>auth.uid() THEN RAISE EXCEPTION '僅限主持人操作'; END IF;
 IF r.status<>'playing' OR r.current_round IS DISTINCT FROM p_round OR r.round_phase<>'result' OR r.settled_round<>p_round THEN RAISE EXCEPTION '請先完成本回合結算'; END IF;
 IF p_round>=r.max_rounds THEN UPDATE public.rooms SET status='finished' WHERE id=r.id;
 ELSE UPDATE public.rooms SET current_round=p_round+1,round_phase='decision' WHERE id=r.id; END IF;
END; $$;
CREATE OR REPLACE FUNCTION public.life_results(p_room_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.rooms%ROWTYPE; pid uuid; hist jsonb; ev jsonb;
BEGIN
 SELECT * INTO r FROM public.rooms WHERE id=p_room_id;
 IF NOT FOUND OR auth.uid() IS NULL THEN RAISE EXCEPTION '無法存取房間'; END IF;
 SELECT id INTO pid FROM public.players WHERE room_id=r.id AND user_id=auth.uid();
 IF r.host_id<>auth.uid() AND pid IS NULL THEN RAISE EXCEPTION '無權存取房間'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.round_number),'[]'::jsonb) INTO ev FROM public.game_events e WHERE e.room_id=r.id AND e.round_number<=r.settled_round;
 IF r.host_id=auth.uid() THEN
 SELECT coalesce(jsonb_agg(jsonb_build_object('nickname',p.nickname,'cash',s.cash,'debt',s.debt,'age',s.age,'state',s.extra_state,'free_days',s.free_days) ORDER BY p.joined_at),'[]'::jsonb) INTO hist FROM public.players p JOIN public.player_states s ON s.player_id=p.id WHERE p.room_id=r.id;
 ELSE SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.round_number),'[]'::jsonb) INTO hist FROM public.round_results x WHERE x.player_id=pid; END IF;
 RETURN jsonb_build_object('host',r.host_id=auth.uid(),'round',r.current_round,'settled',r.settled_round,'phase',r.round_phase,'status',r.status,'history',hist,'events',ev);
END; $$;
REVOKE ALL ON FUNCTION public.life_settle(uuid,integer),public.life_next(uuid,integer),public.life_results(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.life_settle(uuid,integer),public.life_next(uuid,integer),public.life_results(uuid) TO authenticated;
COMMIT;
