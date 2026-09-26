import base64, io, json, os, re, threading, uuid
from datetime import datetime, timezone
from pathlib import Path
from dotenv import load_dotenv
from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
from PIL import Image
load_dotenv()
ROOT=Path(__file__).resolve().parents[1]; MATLAB_DIR=ROOT/'matlab'; SRC_DIR=MATLAB_DIR/'src'; HISTORY=ROOT/'data'/'history'; UPLOADS=ROOT/'backend'/'uploads'
HISTORY.mkdir(parents=True,exist_ok=True); UPLOADS.mkdir(parents=True,exist_ok=True)
DEMO_MODE=os.getenv('DEMO_MODE','false').lower()=='true'; MAX_MB=int(os.getenv('MAX_UPLOAD_MB','15'))
app=Flask(__name__); app.config['MAX_CONTENT_LENGTH']=MAX_MB*1024*1024
CORS(app,resources={r'/api/*':{'origins':os.getenv('FRONTEND_ORIGIN','http://localhost:3000')}})
_engine=None; _lock=threading.Lock()
def engine():
 global _engine
 with _lock:
  if _engine:return _engine
  try: import matlab.engine
  except ImportError as e: raise RuntimeError('MATLAB Engine for Python is unavailable. Set PYTHONPATH to MATLAB R2026a extern/engines/python/dist.') from e
  _engine=matlab.engine.start_matlab(); _engine.cd(str(MATLAB_DIR),nargout=0); _engine.addpath(_engine.genpath(str(SRC_DIR)),nargout=0); return _engine
def clean(x,n=200): return re.sub(r'[\x00-\x1f\x7f]','',str(x or '').strip())[:n]
def demo(): return {'status':'GRADED','qualityLabel':'Accept','qualityScore':92,'feedback':[],'grade':'Moderate DR','gradeIndex':2,'rawConfidence':.88,'calibratedConfidence':.862,'referable':True,'allScores':[{'className':'Healthy','score':.035},{'className':'Mild DR','score':.047},{'className':'Moderate DR','score':.862},{'className':'Severe DR','score':.038},{'className':'Proliferate DR','score':.018}],'exudateCount':18,'darkLesionCount':23,'lesionEvidenceSource':'Demo fixture','icdrQuadrantCounts':[7,4,6,2],'icdrQuadrantsAffected':4,'icdrSevereNPDRFlag':True,'icdrCriteriaText':'Supporting lesion-distribution evidence detected across 4 quadrants; clinical review is required.','evidenceText':'Demo result.','heatmapImageBase64':'','annotatedImageBase64':''}
def run_matlab(path):
 if DEMO_MODE:return demo()
 raw=engine().analyzeRetinalImageAPI(str(path),nargout=1)
 return json.loads(str(raw))
def scores(v):
 if isinstance(v,dict) and 'className' in v:return [{'className':a,'score':float(b)} for a,b in zip(v['className'],v['score'])]
 return [{'className':x.get('className','Unknown'),'score':float(x.get('score',0))} for x in v]
def save(r): (HISTORY/f"{r['id']}.json").write_text(json.dumps(r,indent=2),encoding='utf-8')
@app.get('/api/health')
def health(): return jsonify(ok=True,service='eyeQ Flask API',demoMode=DEMO_MODE)
@app.post('/api/analyze')
def analyze():
 if 'image' not in request.files:return jsonify(error='No fundus image was provided.'),400
 f=request.files['image']; raw=f.read(); tmp=UPLOADS/f'incoming-{uuid.uuid4().hex}.png';
 try:
  Image.open(io.BytesIO(raw)).verify(); tmp.write_bytes(raw); result=run_matlab(tmp); result['allScores']=scores(result.get('allScores',[])); rid=f"PT-{uuid.uuid4().hex[:6].upper()}"; img=UPLOADS/f'{rid}.jpg'; Image.open(io.BytesIO(raw)).convert('RGB').save(img,'JPEG',quality=94)
  r={'id':rid,'createdAt':datetime.now(timezone.utc).isoformat(),'patient':{'patientId':clean(request.form.get('patientId'),64),'age':int(request.form.get('age') or 0),'sex':clean(request.form.get('sex'),32),'diabetesHistory':clean(request.form.get('diabetesHistory'),64),'screenedEye':clean(request.form.get('screenedEye'),32),'cameraDevice':clean(request.form.get('cameraDevice'),120)},'result':result,'imageUrl':f'/api/report/{rid}/image'}; save(r); return jsonify(r)
 except Exception as e: app.logger.exception('Analysis failed'); return jsonify(error=str(e)),500
 finally: tmp.unlink(missing_ok=True)
@app.get('/api/history')
def history():
 rows=[]
 for p in HISTORY.glob('*.json'):
  try: rows.append(json.loads(p.read_text(encoding='utf-8')))
  except: pass
 return jsonify(sorted(rows,key=lambda x:x.get('createdAt',''),reverse=True))
@app.get('/api/report/<rid>')
def report(rid):
 p=HISTORY/f'{clean(rid,64)}.json'
 return (jsonify(json.loads(p.read_text(encoding='utf-8'))) if p.exists() else (jsonify(error='Report not found.'),404))
@app.get('/api/report/<rid>/image')
def image(rid):
 p=UPLOADS/f'{clean(rid,64)}.jpg'; return send_file(p,mimetype='image/jpeg') if p.exists() else (jsonify(error='Image not found.'),404)
@app.get('/api/report/<rid>/pdf')
def pdf(rid):
 p=HISTORY/f'{clean(rid,64)}.json'
 if not p.exists():return jsonify(error='Report not found.'),404
 r=json.loads(p.read_text(encoding='utf-8')); from reportlab.lib.pagesizes import A4; from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle; from reportlab.lib import colors; from reportlab.lib.styles import getSampleStyleSheet; from reportlab.lib.units import mm; import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
 out=io.BytesIO(); doc=SimpleDocTemplate(out,pagesize=A4,rightMargin=14*mm,leftMargin=14*mm,topMargin=14*mm,bottomMargin=14*mm); st=getSampleStyleSheet(); res=r['result']; story=[Paragraph('eyeQ AI — Diabetic Retinopathy Screening Report',st['Title']),Paragraph(f"Report {r['id']} · {r['createdAt']}",st['Normal']),Spacer(1,8)]
 p=r['patient']; story.append(Table([['Patient ID',p.get('patientId'),'Age/Sex',f"{p.get('age')} / {p.get('sex')}"],['Diabetes',p.get('diabetesHistory'),'Eye',p.get('screenedEye')],['Quality',f"{res.get('qualityLabel')} · {res.get('qualityScore',0)}/100",'Grade',f"{res.get('grade','—')} · ICDR {res.get('gradeIndex','—')}"]],colWidths=[25*mm,55*mm,25*mm,65*mm],style=[('GRID',(0,0),(-1,-1),.4,colors.HexColor('#dfe5ec')),('BACKGROUND',(0,0),(-1,-1),colors.HexColor('#f7f4ef')),('FONTSIZE',(0,0),(-1,-1),8)])); story += [Spacer(1,10),Paragraph(f"Calibrated confidence: {float(res.get('calibratedConfidence',0))*100:.1f}% · {'Referable' if res.get('referable') else 'Non-referable'}",st['Heading2'])]
 ss=res.get('allScores',[]); fig,ax=plt.subplots(figsize=(7,2.5)); ax.bar([x['className'] for x in ss],[x['score']*100 for x in ss]); ax.set_ylabel('Probability (%)'); ax.set_ylim(0,100); fig.tight_layout(); b=io.BytesIO(); fig.savefig(b,format='png',dpi=150); plt.close(fig); b.seek(0); from reportlab.platypus import Image as RI; story += [RI(b,width=170*mm,height=60*mm),Paragraph(str(res.get('evidenceText','')).replace('\n','<br/>'),st['BodyText']),Spacer(1,8),Paragraph('Clinical safety note',st['Heading2']),Paragraph('AI-assisted screening only. This report is not a standalone diagnosis. Review referable or uncertain cases clinically.',st['BodyText']),Spacer(1,10),Paragraph('Developed by Team Alphabet.',st['BodyText'])]; doc.build(story); out.seek(0); return send_file(out,mimetype='application/pdf',as_attachment=True,download_name=f'eyeQ-{rid}.pdf')
@app.errorhandler(413)
def too_large(e): return jsonify(error=f'Image exceeds {MAX_MB} MB.'),413
if __name__=='__main__': app.run(host=os.getenv('HOST','127.0.0.1'),port=int(os.getenv('PORT','5000')),debug=False)
