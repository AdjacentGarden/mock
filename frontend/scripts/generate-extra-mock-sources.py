#!/usr/bin/env python3
"""Preserve the additional shelf/discovery outlines as local demo source records."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
community=json.loads((ROOT/'Resources/Data/community.json').read_text())
shelf=json.loads((ROOT/'Resources/Data/shelf.json').read_text())
config=[('catalog_theoretical_mechanics_1','community_theoretical_mechanics','mechanics',[1,2,3,4,5,8,12]),
 ('community_ecology','community_ecology','ecology',[1,2,3]),
 ('community_motion','community_motion','motion',[1,2,3]),
 ('community_functions','community_functions','functions',[1,2,3])]
result=[]
def source(id,title,cover,chapters):
 return {'summary':{'book_id':id,'title':title,'filename':title+'.pdf','cover_url':cover,'status':'ready',
  'page_count':max(c['page_end'] for c in chapters),'chapter_count':len([c for c in chapters if c.get('parent_id') is None]),
  'chunk_count':0,'asset_count':0,'average_confidence':100,'updated_at':1793952000,'content_mode':'mock_outline'},
  'chapters':chapters,'lessons':[],'chunks':[],'assets':[],'flashcards':[],'quizzes':[],
  'plan':{'user_id':'mock_learner','book_id':id,'days':len(chapters),'daily_minutes':25,'tasks':[]}}
def chapter(id,title,page,level=1,parent=None):
 return {'chapter_id':id,'source_title':title,'ai_title':title,'level':level,'page_start':page,'page_end':page,
 'confidence':100,'status':'confirmed','source':'authored-mock-outline','parent_id':parent}
for id,cid,prefix,indices in config:
 entry=next(c for c in community if c['id']==cid)
 chapters=[chapter(f'{prefix}-c{index}' if prefix=='mechanics' else f'{prefix}-{index}',title,i+1)
  for i,(index,title) in enumerate(zip(indices,entry['chapters']))]
 result.append(source(id,entry['catalogTitle'],entry['cover'],chapters))
entry=next(s for s in shelf if s['bookId']=='catalog_micro_psychology_set')
groups=[('表情观察',['可观察特征与情绪假设','面部动作与情境线索','短暂表情的连续观察']),
 ('动作观察',['姿态、手势与交流功能','个体基线与行为变化','空间距离与互动节奏']),
 ('反应与沟通',['反应时序与问题情境','多种线索的交叉核对','观察记录与澄清提问'])]
chapters=[];page=1
for i,(title,items) in enumerate(groups,1):
 parent=f'psychology-c{i}';chapters.append(chapter(parent,title,page));chapters[-1]['page_end']=page+2
 for j,item in enumerate(items,1):chapters.append(chapter(f'{parent}-s{j}',item,page,2,parent));page+=1
result.append(source(entry['bookId'],entry['title'],entry['coverUrl'],chapters))
(ROOT/'Resources/Data/MockBooks/extra-sources.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('Wrote',len(result),'additional shelf/discovery source records')
