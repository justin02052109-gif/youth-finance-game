BEGIN;
CREATE OR REPLACE FUNCTION public.life_settle(p_room_id uuid,p_round integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
#variable_conflict use_variable
DECLARE r public.rooms%ROWTYPE; p record; s public.player_states%ROWTYPE; o jsonb; a jsonb; opts jsonb; st jsonb; winners jsonb; chosen text; n numeric; loan numeric; cash_end numeric; debt_end numeric; study jsonb; skills jsonb; exp jsonb; experiences jsonb; degree integer; k text; progress numeric; event_text text; repayment numeric;
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
  repayment:=coalesce((p.decision_data->>'repay')::numeric,0)/10000;
  IF repayment<0 OR repayment>least(cash_end,s.debt::numeric/10000) THEN RAISE EXCEPTION '還款超過可用資金或原有負債'; END IF;
  cash_end:=cash_end-repayment; debt_end:=debt_end-repayment;
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
  VALUES(p.id,p_round,17+p_round,round((o->>'salary')::numeric*10000)::bigint,round(((o->>'salary')::numeric-(o->>'net')::numeric+(a->>'cost')::numeric)*10000)::bigint,round(cash_end*10000)::bigint,round(debt_end*10000)::bigint,jsonb_build_object('requested',p.main_choice,'actual',o->>'name','fallback_used',chosen<>p.main_choice,'category',o->>'cat','activity',a->>'name','loan',loan,'repaid',repayment,'education_cost',o->'fee','free_days',o->'free','used_days',a->'days','activity_cost',a->'cost','net',(o->>'net')::numeric-(a->>'cost')::numeric,'before',s.extra_state,'after',st));
 END LOOP;
 event_text:=CASE p_round WHEN 3 THEN '教育及職訓資源增加：下一年度升學補助3萬元、職訓費用減半。' WHEN 6 THEN '新興產業發展：下一年度資訊及水電職缺年薪增加6萬元。' WHEN 9 THEN '產業轉型：下一年度設計、行政職缺年薪增加3萬元。' WHEN 12 THEN '在職進修資源增加：下一年度升學補助3萬元、職訓費用減半。' WHEN 15 THEN '服務與技術需求增加：下一年度行政、水電及照顧職缺年薪增加6萬元。' ELSE NULL END;
 IF event_text IS NOT NULL THEN INSERT INTO public.game_events(room_id,round_number,event_type,title,description) VALUES(r.id,p_round,'common','共同事件',event_text); END IF;
 UPDATE public.rooms SET settled_round=p_round,round_phase='result' WHERE id=r.id;
END; $$;

CREATE OR REPLACE FUNCTION public.life_submit_budget(p_room_id uuid,p_round integer,p_main text,p_activity text,p_fallback text,p_accept_debt boolean,p_repay bigint)
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
 IF p_repay IS NULL OR p_repay<0 OR p_repay>s.debt OR p_repay>greatest(0,(v_cash+(o->>'net')::numeric-(a->>'cost')::numeric)*10000) OR (f IS NOT NULL AND p_repay>greatest(0,(v_cash+(f->>'net')::numeric-(a->>'cost')::numeric)*10000)) THEN RAISE EXCEPTION '還款超過可用資金或原有負債'; END IF;
 INSERT INTO public.decisions(player_id,round_number,main_choice,experience_choice,decision_data)
 VALUES(p.id,p_round,p_main,p_activity,jsonb_build_object('fallback',p_fallback,'accept_debt',coalesce(p_accept_debt,false),'repay',p_repay))
 ON CONFLICT(player_id,round_number) DO UPDATE SET main_choice=excluded.main_choice,experience_choice=excluded.experience_choice,decision_data=excluded.decision_data,submitted_at=now();
END; $$;

REVOKE ALL ON FUNCTION public.life_submit_budget(uuid,integer,text,text,text,boolean,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.life_submit_budget(uuid,integer,text,text,text,boolean,bigint) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.life_repay(uuid,integer,bigint,bigint,bigint) FROM authenticated;
COMMIT;
