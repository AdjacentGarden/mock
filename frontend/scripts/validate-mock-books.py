#!/usr/bin/env python3
"""Check every authored book and its local learning/media fixture contract."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
sources=json.loads((ROOT/'Resources/Data/sources.json').read_text())+json.loads((ROOT/'Resources/Data/MockBooks/extra-sources.json').read_text())
errors=[];totals={'books':0,'lessons':0,'blocks':0,'cards':0,'quizzes':0,'diagrams':0,'handouts':0,'videos':0}
def check(ok,message):
 if not ok:errors.append(message)
for source in sources:
 id=source['summary']['book_id']
 if id=='book_biology_2':continue
 path=ROOT/'Resources/Data/MockBooks'/f'{id}.json'
 if not path.exists():errors.append(f'Missing book: {id}');continue
 book=json.loads(path.read_text());totals['books']+=1
 parents={c.get('parent_id') for c in source['chapters'] if c.get('parent_id')}
 leaves={c['chapter_id'] for c in source['chapters'] if c['chapter_id'] not in parents}
 topics=book['topics'];ids=[t['chapter_id'] for t in topics]
 check(book['book_id']==id and book['version']==2,f'{id}: wrong ownership/version')
 check(set(ids)==leaves and len(ids)==len(leaves),f'{id}: incomplete/duplicate chapter coverage')
 for t in topics:
  tag=id+'/'+t['chapter_id'];totals['lessons']+=1
  check(len(t['objectives'])==3 and len(t['key_concepts'])==6,tag+': missing objectives/concepts')
  check(len(t['blocks'])==4 and {b['block_type'] for b in t['blocks']}=={'explanation','diagram','comparison','application'},tag+': wrong teaching blocks')
  for b in t['blocks']:
   totals['blocks']+=1;check(len(b['content'])>=100,tag+': short teaching block '+b['title'])
  check(len(t['flashcards'])==6 and len({c['front'] for c in t['flashcards']})==6,tag+': six distinct cards required')
  check(all(c['front'].strip() and c['back'].strip() for c in t['flashcards']),tag+': empty card')
  totals['cards']+=len(t['flashcards']);totals['quizzes']+=len(t['quizzes'])
  check(len(t['quizzes'])==3 and {q['question_type'] for q in t['quizzes']}=={'judgment','choice','short-answer'},tag+': wrong question bank')
  for q in t['quizzes']:
   check(bool(q['answer']) and bool(q['explanation']),tag+': incomplete answer/explanation')
   if q['question_type']!='short-answer':check(q['answer'] in q['choices'],tag+': answer absent from choices')
  check(len(t['diagram_steps'])==3 and bool(t['diagram_focus']),tag+': incomplete diagram semantics')
  for kind,suffix in [('diagrams','-diagram.png'),('handouts','-handout.png'),('videos','.mp4')]:
   asset=ROOT/'Resources/Content/assets/mock-books'/id/(t['chapter_id']+suffix)
   check(asset.is_file(),tag+': missing '+kind)
   if asset.is_file():
    totals[kind]+=1
    with asset.open('rb') as f:header=f.read(16)
    check(header.startswith(b'\x89PNG') if suffix.endswith('png') else b'ftyp' in header,tag+': invalid '+kind)
check(totals['books']==10 and totals['lessons']==220,'Expected 10 other books/courses and 220 complete chapter topics')
if errors:raise SystemExit('\n'.join(errors))
print('Mock book fixtures validated: '+json.dumps(totals,ensure_ascii=False))
