BEGIN;
CREATE TABLE IF NOT EXISTS public.life_rules (
  version text PRIMARY KEY,
  rules jsonb NOT NULL
);
ALTER TABLE public.life_rules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.life_rules FROM PUBLIC, anon, authenticated;
INSERT INTO public.life_rules(version,rules) VALUES ('v5','{"education":[["uni","一般大學",4,6,5,"大學"],["tech","科技大學",4,5,4,"大學"],["college","專科教育",2,4.5,4,"專科"],["master","碩士班",2,8,3,"碩士"]],"skills":[["水電",4,4],["維修",5,4],["資訊",6,3],["美容",4.5,4],["餐飲",4,4],["設計",5,4],["照顧",2,5],["行銷",3.5,4],["外語",3,4],["財務管理",4,4],["數據分析",5,4],["研究分析",5,4],["經營管理",4,4]],"jobs":[["門市人員",36,"零售",0,"",0,5,"輪班"],["餐飲服務員",39,"餐飲",0,"",0,3,"排班"],["工廠作業員",42,"製造",0,"",0,3,"輪班"],["行政助理",39,"行政",0,"",0,6,"固定休假"],["物流人員",42,"物流",0,"",0,4,"排班"],["業務助理",42,"業務",0,"",0,4,"業績壓力"],["水電技術員",54,"水電",0,"水電",0,4,"外勤"],["維修技師",51,"維修",0,"維修",0,4,"排班"],["程式設計師",60,"資訊",0,"資訊",0,4,"專案工作"],["美髮設計師",48,"美容",0,"美容",0,3,"假日排班"],["烘焙技術員",48,"餐飲",0,"餐飲",0,3,"早班"],["平面設計師",51,"設計",0,"設計",0,5,"專案工作"],["照顧服務員",48,"照顧",0,"照顧",0,4,"排班"],["行銷專員",48,"業務",0,"行銷",0,4,"專案工作"],["行政專員",48,"行政",2,"",0,6,"固定休假"],["儲備幹部",57,"零售",2,"",0,3,"管理培訓"],["工程師",72,"資訊",2,"資訊",0,3,"專案工作"],["研究助理",54,"研究",2,"",0,5,"研究工作"],["研究專員",72,"研究",3,"",0,4,"研究工作"],["門市店長",54,"零售",0,"",3,3,"管理責任"],["餐飲主管",60,"餐飲",0,"",3,2,"長工時"],["工廠組長",60,"製造",0,"",3,3,"輪班管理"],["資深水電技師",78,"水電",0,"水電",3,4,"外勤"],["資深程式設計師",90,"資訊",0,"資訊",4,4,"專案工作"],["資深設計師",72,"設計",0,"設計",4,5,"專案工作"],["行政主管",66,"行政",2,"",4,4,"管理責任"],["海外業務",96,"業務",2,"外語",2,3,"海外工作",[2,5,8,11,14,17]],["AI研發工程師",156,"資訊",3,"資訊",2,2,"高強度專案",[4,7,10,12,15,17]],["自由接案設計師",60,"設計",0,"設計",2,8,"收入可能波動",[3,6,9,12,15]],["綠能技師",90,"水電",0,"水電",2,3,"外勤",[1,4,7,10,13,16]],["公益行政",48,"行政",0,"",1,7,"固定休假",[2,5,8,11,14,17]],["區域經理",84,"零售",0,"",6,3,"跨店管理"],["工程承包主管",108,"水電",0,"水電",6,3,"工程管理"],["資深工程師",108,"資訊",2,"資訊",3,4,"專案工作"],["研發工程師",90,"資訊",3,"資訊",0,4,"研發工作"],["資深研發工程師",132,"資訊",3,"資訊",3,3,"研發專案"],["研發主管",150,"資訊",2,"資訊",6,3,"團隊管理"],["技術總監",180,"資訊",3,"資訊",7,2,"技術管理"],["財務專員",60,"財務",2,"財務管理",0,5,"固定休假"],["數據分析師",78,"資訊",2,"數據分析",0,5,"分析工作"],["研究分析員",84,"研究",3,"研究分析",0,5,"研究工作"],["營運專員",60,"行政",2,"經營管理",0,5,"營運管理"],["跨國企業經理",150,"業務",2,"外語、行銷",5,2,"跨國管理",[7,10,13,16]],["半導體工程師",120,"資訊",2,"資訊",2,3,"專案與輪班",[3,6,9,12,15,17]],["科技研發主管",200,"資訊",3,"資訊",5,2,"高強度研發",[9,12,15,17]],["企業財務主管",132,"財務",2,"財務管理",5,3,"財務管理",[7,10,13,16]],["資深數據分析師",108,"資訊",2,"數據分析",1,5,"分析專案",[2,5,8,11,14,17]],["研究機構研究員",108,"研究",3,"研究分析",1,5,"研究工作",[3,6,9,12,15,17]],["國際研究專案主管",168,"研究",3,"研究分析、外語",4,3,"國際研究",[8,11,14,17]],["大型企業營運主管",180,"行政",2,"經營管理",6,2,"營運管理",[9,12,15,17]],["高階水電技師",108,"水電",0,"水電",5,4,"外勤",[4,7,10,13,16]],["精密設備維修技師",120,"維修",0,"維修",5,3,"精密維修",[3,6,9,12,15,17]],["獨立設計接案者",96,"設計",0,"設計",4,7,"彈性接案",[4,7,10,13,16]],["高績效業務人員",132,"業務",0,"行銷",5,2,"業績壓力",[5,8,11,14,17]],["連鎖門市區域主管",96,"零售",0,"",6,3,"跨店管理",[4,7,10,13,16]],["專業餐飲主廚",108,"餐飲",0,"餐飲",5,2,"餐飲管理",[3,6,9,12,15,17]]],"goals":["高收入","財務安全","專業成就","工作穩定","自由生活","家庭陪伴","世界探索","終身學習"]}'::jsonb)
ON CONFLICT (version) DO UPDATE SET rules=excluded.rules;

ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS round_phase text NOT NULL DEFAULT 'decision';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS rules_version text NOT NULL DEFAULT 'v5';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS settled_round integer NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public.life_options(p_state jsonb,p_round integer,p_version text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $$
DECLARE
 r jsonb; e jsonb; j jsonb; a jsonb := '[]'::jsonb;
 ident text; title text; fee numeric; years numeric; progress numeric;
 eligible boolean; bonus numeric; salary numeric; industry text; skill text;
 degree int := coalesce((p_state->>'degree')::int,0);
 d int; t int; exp numeric; special boolean;
BEGIN
 SELECT rules INTO STRICT r FROM public.life_rules WHERE version=p_version;
 FOR e IN SELECT value FROM jsonb_array_elements(r->'education') LOOP
  ident:=e->>0; title:=e->>1; years:=(e->>2)::numeric;
  fee:=(e->>3)::numeric-CASE WHEN p_round IN (4,13) THEN 3 ELSE 0 END;
  progress:=coalesce((p_state->'study'->>ident)::numeric,0);
  eligible:=progress<years AND (ident<>'master' OR degree>=2);
  t:=(ARRAY[45,65,75,90,100,110,125,140])[(e->>4)::int];
  a:=a||jsonb_build_array(jsonb_build_object('id',ident,'name',title,'cat','教育','ok',eligible,'salary',0,'fee',fee,'net',-12-fee,'free',t,'study',ident,'inc',1,'len',years,'degree',CASE ident WHEN 'master' THEN 3 WHEN 'college' THEN 1 ELSE 2 END));
  a:=a||jsonb_build_array(jsonb_build_object('id',ident||'half','name',title||'・半工半讀','cat','教育','ok',eligible,'salary',18,'fee',fee,'net',6-fee,'free',45,'study',ident,'inc',0.5,'len',years,'degree',CASE ident WHEN 'master' THEN 3 WHEN 'college' THEN 1 ELSE 2 END,'industry','兼職','exp',0.5));
 END LOOP;
 FOR e IN SELECT value FROM jsonb_array_elements(r->'skills') LOOP
  title:=e->>0; fee:=(e->>1)::numeric*CASE WHEN p_round IN (4,13) THEN 0.5 ELSE 1 END;
  t:=(ARRAY[45,65,75,90,100,110,125,140])[(e->>2)::int];
  a:=a||jsonb_build_array(jsonb_build_object('id','skill'||title,'name',title||'技能培訓','cat','職訓','ok',NOT(coalesce(p_state->'skills','[]'::jsonb)?title),'salary',0,'fee',fee,'net',-12-fee,'free',t,'skill',title));
 END LOOP;
 FOR j IN SELECT value FROM jsonb_array_elements(r->'jobs') LOOP
  special:=jsonb_array_length(j)>8;
  IF special AND NOT (j->8 @> jsonb_build_array(p_round)) THEN CONTINUE; END IF;
  title:=j->>0; salary:=(j->>1)::numeric; industry:=j->>2; d:=(j->>3)::int; skill:=j->>4; exp:=(j->>5)::numeric;
  eligible:=degree>=d AND coalesce((p_state->'exp'->>industry)::numeric,0)>=exp AND (skill='' OR coalesce(p_state->'skills','[]'::jsonb) @> to_jsonb(string_to_array(skill,'、')));
  bonus:=CASE WHEN p_round=7 AND industry IN ('資訊','水電') THEN 6 WHEN p_round=10 AND industry IN ('設計','行政') THEN 3 WHEN p_round=16 AND industry IN ('行政','水電','照顧') THEN 6 ELSE 0 END;
  t:=(ARRAY[45,65,75,90,100,110,125,140])[(j->>6)::int];
  IF title='行政助理' THEN t:=110; ELSIF title='自由接案設計師' THEN t:=140; END IF;
  a:=a||jsonb_build_array(jsonb_build_object('id',title,'name',title,'cat',CASE WHEN special THEN '特殊職缺' ELSE '就業' END,'ok',eligible,'salary',salary+bonus,'fee',0,'net',salary+bonus-12,'free',t,'industry',industry,'exp',1,'min_degree',d,'required_skill',skill,'required_exp',exp,'condition',j->>7));
 END LOOP;
 RETURN a||'[
 {"id":"travel","cat":"人生選擇","name":"海外打工度假","ok":true,"net":6,"salary":30,"fee":0,"free":110,"experience":"海外打工度假","industry":"服務","exp":1},
 {"id":"rest","cat":"人生選擇","name":"休息與生涯探索","ok":true,"net":-12,"salary":0,"fee":0,"free":140,"experience":"生涯探索"},
 {"id":"care","cat":"人生選擇","name":"家庭照顧","ok":true,"net":-12,"salary":0,"fee":0,"free":75,"experience":"家庭照顧"}]'::jsonb;
END;
$$;
REVOKE ALL ON FUNCTION public.life_options(jsonb,integer,text) FROM PUBLIC,anon,authenticated;
COMMIT;
