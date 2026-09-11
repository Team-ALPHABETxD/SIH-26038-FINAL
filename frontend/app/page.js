'use client';

import { useEffect, useRef, useState } from 'react';
import {
  Activity,
  ArrowRight,
  Check,
  ChevronDown,
  CircleAlert,
  FileText,
  Gauge,
  HeartPulse,
  Info,
  Microscope,
  RefreshCw,
  ShieldCheck,
  Sparkles,
  UploadCloud
} from 'lucide-react';

const grades = [
  'Healthy',
  'Mild DR',
  'Moderate DR',
  'Severe DR',
  'Proliferate DR'
];

/*
  IMPORTANT:
  These keys must exactly match the keys returned
  by the Flask/MATLAB backend.
*/
const scoreKeys = [
  'Healthy',
  'MildDR',
  'ModerateDR',
  'SevereDR',
  'ProliferateDR'
];

/*
  Flask backend.
  Direct connection avoids Next.js multipart/proxy issues.
*/
const API_BASE = 'http://127.0.0.1:5000';

const backendPath = p => {
  if (!p) return '';

  if (
    p.startsWith('http://') ||
    p.startsWith('https://')
  ) {
    return p;
  }

  return `${API_BASE}${p}`;
};


export default function Home() {

  const inputRef = useRef(null);

  const [file, setFile] = useState(null);
  const [preview, setPreview] = useState('');
  const [drag, setDrag] = useState(false);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const [health, setHealth] = useState(null);
  const [result, setResult] = useState(null);
  const [evaluation, setEvaluation] = useState(null);


  // ==========================================================
  // IMAGE PICKER
  // ==========================================================

  function pick(selectedFile) {

    if (!selectedFile) return;

    const allowedTypes = [
      'image/png',
      'image/jpeg',
      'image/jpg',
      'image/tiff',
      'image/bmp'
    ];

    const maxSize = 15 * 1024 * 1024;

    if (!allowedTypes.includes(selectedFile.type)) {

      setError(
        'Unsupported image format. Please use JPG, PNG, TIFF, or BMP.'
      );

      return;
    }

    if (selectedFile.size > maxSize) {

      setError(
        'Image is too large. Maximum size is 15 MB.'
      );

      return;
    }

    setFile(selectedFile);
    setError('');
    setResult(null);

    const url = URL.createObjectURL(selectedFile);

    setPreview(prev => {

      if (prev) {
        URL.revokeObjectURL(prev);
      }

      return url;
    });
  }


  // ==========================================================
  // LOAD EVALUATION
  // ==========================================================

  async function loadEvaluation() {

    try {

      const r = await fetch(
        `${API_BASE}/api/evaluation`,
        {
          cache: 'no-store'
        }
      );

      const text = await r.text();

      let d;

      try {

        d = JSON.parse(text);

      } catch {

        console.error(
          'Evaluation API returned non-JSON:',
          text
        );

        throw new Error(
          'Invalid evaluation response.'
        );
      }

      if (!r.ok || !d.ok) {

        throw new Error(
          d.error ||
          d.message ||
          'Could not load evaluation metrics.'
        );
      }

      setEvaluation(d);

    } catch (e) {

      console.error(
        'Evaluation loading failed:',
        e
      );

      setEvaluation(null);
    }
  }


  // ==========================================================
  // INITIAL LOAD
  // ==========================================================

  useEffect(() => {

    fetch(
      `${API_BASE}/api/health`,
      {
        cache: 'no-store'
      }
    )
      .then(async r => {

        const text = await r.text();

        try {

          return JSON.parse(text);

        } catch {

          throw new Error(
            'Invalid health response.'
          );
        }
      })

      .then(setHealth)

      .catch(err => {

        console.error(
          'Health check failed:',
          err
        );

        setHealth({
          matlabIntegration: false
        });
      });


    loadEvaluation();


    return () => {

      setPreview(current => {

        if (current) {
          URL.revokeObjectURL(current);
        }

        return '';
      });
    };

  }, []);


  // ==========================================================
  // ANALYZE IMAGE
  // ==========================================================

  async function analyze() {

    if (!file) {

      setError(
        'Please select a retinal image first.'
      );

      return;
    }

    setLoading(true);
    setError('');
    setResult(null);

    try {

      const fd = new FormData();

      fd.append(
        'image',
        file
      );


      console.log(
        'Sending image to Flask:',
        `${API_BASE}/api/analyze`
      );


      const r = await fetch(
        `${API_BASE}/api/analyze`,
        {
          method: 'POST',
          body: fd
        }
      );


      const text = await r.text();


      console.log(
        'Flask response status:',
        r.status
      );

      console.log(
        'Flask response:',
        text
      );


      let d;

      try {

        d = JSON.parse(text);

      } catch {

        throw new Error(
          `Backend returned invalid JSON (${r.status}). Flask response: ${text.slice(0, 500)}`
        );
      }


      if (!r.ok || !d.ok) {

        throw new Error(
          d.error ||
          d.message ||
          `Analysis failed with HTTP ${r.status}.`
        );
      }


      setResult(d);


      setTimeout(() => {

        document
          .getElementById('results')
          ?.scrollIntoView({
            behavior: 'smooth'
          });

      }, 50);


    } catch (e) {

      console.error(
        'Analysis error:',
        e
      );

      setError(
        e.message ||
        'Could not analyze the image.'
      );

    } finally {

      setLoading(false);
    }
  }


  const quality =
    result?.qualityScore ?? null;


  const conf =
    result?.calibratedConfidence
      ? result.calibratedConfidence * 100
      : 0;


  return (

    <main>

      <Nav health={health} />


      {/* ====================================================
          HERO
      ==================================================== */}

      <section className="hero shell">

        <div className="hero-copy reveal">

          <div className="eyebrow">

            <span className="pill">

              <Sparkles size={13} />

              Explainable AI

            </span>

            RETINAL SCREENING

          </div>


          <h1>

            See the signal.
            <br />

            <em>
              Understand the model.
            </em>

          </h1>


          <p>

            DR-xAI combines fundus-image quality
            assessment, five-level ICDR grading,
            calibrated confidence and visual
            explanations in one research-ready
            screening interface.

          </p>


          <div className="hero-actions">

            <button
              className="primary"
              onClick={() =>
                document
                  .getElementById('screen')
                  ?.scrollIntoView({
                    behavior: 'smooth'
                  })
              }
            >

              Analyze a fundus image

              <ArrowRight size={17} />

            </button>


            <a href="#method">

              How it works

              <ChevronDown size={16} />

            </a>

          </div>


          <div className="trust-row">

            <span>

              <ShieldCheck size={15} />

              Research backed

            </span>


            <span>

              <Activity size={15} />

              MATLAB inference engine

            </span>

          </div>

        </div>


        <div className="hero-visual reveal delay">

          <div className="orbital o1" />
          <div className="orbital o2" />


          <div className="retina-art">

            <div className="retina-veins v1" />
            <div className="retina-veins v2" />
            <div className="retina-veins v3" />

            <div className="disc" />
            <div className="fovea" />

          </div>


          <div className="float-card fc1">

            <Gauge size={16} />

            <span>

              Quality gate

              <strong>
                0—100
              </strong>

            </span>

          </div>


          <div className="float-card fc2">

            <Microscope size={16} />

            <span>

              Explainable

              <strong>
                Grad-CAM
              </strong>

            </span>

          </div>

        </div>

      </section>


      {/* ====================================================
          SCREENING
      ==================================================== */}

      <section
        id="screen"
        className="section shell"
      >

        <div className="section-heading">

          <div>

            <div className="kicker">
              01 / SCREENING
            </div>

            <h2>
              Upload a retinal image
            </h2>

          </div>


          {/* <p>

            The browser sends the image directly
            to the Flask API, which invokes your
            original MATLAB pipeline.

          </p> */}

        </div>


        <div className="screen-grid">


          {/* UPLOAD CARD */}

          <div
            className={
              'upload-card ' +
              (drag ? 'dragging' : '')
            }

            onDragOver={e => {

              e.preventDefault();

              setDrag(true);

            }}

            onDragLeave={() =>
              setDrag(false)
            }

            onDrop={e => {

              e.preventDefault();

              setDrag(false);

              pick(
                e.dataTransfer.files?.[0]
              );

            }}

            onClick={() =>
              inputRef.current?.click()
            }
          >

            <input
              ref={inputRef}
              type="file"
              hidden
              accept="image/png,image/jpeg,image/jpg,image/tiff,.bmp"
              onChange={e =>
                pick(
                  e.target.files?.[0]
                )
              }
            />


            {!preview ? (

              <>

                <div className="upload-icon">

                  <UploadCloud size={26} />

                </div>


                <h3>
                  Drop fundus image here
                </h3>


                <p>

                  or click to browse · JPG,
                  PNG, TIFF, BMP · max 15 MB

                </p>


                <div className="mini-hint">

                  <Check size={14} />

                  Works with the same image
                  format used by the MATLAB
                  pipeline

                </div>

              </>

            ) : (

              <>

                <div className="preview-frame">

                  <img
                    src={preview}
                    alt="Selected fundus image"
                  />

                </div>


                <div className="file-name">

                  {file?.name}

                </div>


                <button
                  className="ghost"
                  onClick={e => {

                    e.stopPropagation();

                    inputRef.current?.click();

                  }}
                >

                  Choose another

                </button>

              </>

            )}


            {file && (

              <button
                className="primary full"
                disabled={loading}
                onClick={e => {

                  e.stopPropagation();

                  analyze();

                }}
              >

                {loading ? (

                  <>

                    <span className="spinner" />

                    Running MATLAB pipeline…

                  </>

                ) : (

                  <>

                    Analyze image

                    <ArrowRight size={16} />

                  </>

                )}

              </button>

            )}


            {error && (

              <div className="error">

                <CircleAlert size={15} />

                {error}

              </div>

            )}

          </div>


          {/* QUALITY CARD */}

          <div className="quality-card">

            <div className="card-top">

              <span>
                MODEL STATUS
              </span>


              <span
                className={
                  'status ' +
                  (
                    health?.matlabIntegration
                      ? 'online'
                      : 'offline'
                  )
                }
              >

                <i />


                {
                  health?.matlabIntegration
                    ? 'MATLAB bridge ready'
                    : 'Bridge needs setup'
                }

              </span>

            </div>


            <div className="quality-intro">

              <div className="quality-icon">

                <HeartPulse size={20} />

              </div>


              <div>

                <h3>
                  Image quality gate
                </h3>

                <p>

                  Sharpness, illumination and
                  retinal field-of-view are checked
                  before grading.

                </p>

              </div>

            </div>


            <div className="quality-meter">

              <div className="meter-ring">

                <strong>

                  {
                    quality === null
                      ? '—'
                      : Math.round(quality)
                  }

                </strong>


                <span>
                  / 100
                </span>

              </div>


              <div>

                <div className="label">
                  CURRENT RESULT
                </div>


                <div
                  className={
                    'quality-label ' +
                    (result?.qualityLabel || '')
                  }
                >

                  {
                    result?.qualityLabel ||
                    'Awaiting image'
                  }

                </div>


                <p>

                  {
                    result?.feedback?.length
                      ? result.feedback[0]
                      : 'A fast rule-based gate protects the downstream grading step from unsuitable images.'
                  }

                </p>

              </div>

            </div>


            {result?.status === 'REJECTED' && (

              <div className="notice reject">

                <CircleAlert size={16} />

                <span>

                  <b>
                    Image rejected.
                  </b>

                  {' '}

                  Recapture using the feedback above.

                </span>

              </div>

            )}

          </div>

        </div>

      </section>


      {/* ====================================================
          RESULTS
      ==================================================== */}

      {result?.status === 'GRADED' && (
        <Results result={result} />
      )}


      {/* ====================================================
          METHODOLOGY
      ==================================================== */}

      <Method />


      {/* ====================================================
          EVALUATION
      ==================================================== */}

      <Evaluation
        data={evaluation}
        onRefresh={loadEvaluation}
      />


      {/* ====================================================
          FOOTER
      ==================================================== */}

      <Footer />

    </main>
  );
}


// ============================================================
// RESULTS
// ============================================================

function Results({ result: r }) {

  const conf =
    Math.max(
      0,
      Math.min(
        1,
        Number(
          r.calibratedConfidence || 0
        )
      )
    ) * 100;


  const scores =
    r.allScores || {};


  return (

    <section
      id="results"
      className="section shell results"
    >

      <div className="section-heading">

        <div>

          <div className="kicker">
            02 / EXPLANATION
          </div>

          <h2>
            Analysis, not just a label
          </h2>

        </div>


        <span className="result-chip">

          <Check size={13} />

          Pipeline complete

        </span>

      </div>


      <div className="result-grid">


        {/* GRADE */}

        <div className="grade-card">

          <div className="grade-eyebrow">
            ICDR SEVERITY GRADE
          </div>


          <div className="grade-number">
            {r.gradeIndex}
          </div>


          <h3>
            {r.grade}
          </h3>


          <p>

            {
              r.referable
                ? 'Referable DR · Grade ≥ 2'
                : 'Not referable under the configured Grade ≥ 2 threshold'
            }

          </p>


          <div className="confidence">

            <div className="conf-head">

              <span>
                Calibrated confidence
              </span>

              <b>
                {conf.toFixed(1)}%
              </b>

            </div>


            <div className="progress">

              <i
                style={{
                  width: conf + '%'
                }}
              />

            </div>


            <small>

              Platt-scaled probability that
              the prediction is correct.

            </small>

          </div>

        </div>


        {/* SCORES */}

        <div className="scores-card">

          <div className="card-title">

            Class probability profile

          </div>


          {grades.map((g, i) => {

            const v =
              Math.max(
                0,
                Math.min(
                  1,
                  Number(
                    scores[
                      scoreKeys[i]
                    ] || 0
                  )
                )
              ) * 100;


            return (

              <div
                className="score-row"
                key={g}
              >

                <span>
                  {g}
                </span>


                <div className="bar">

                  <i
                    style={{
                      width: v + '%'
                    }}
                  />

                </div>


                <b>
                  {v.toFixed(1)}%
                </b>

              </div>

            );

          })}


          <div className="referable-row">

            <span>
              Referable signal
            </span>


            <b
              className={
                r.referable
                  ? 'yes'
                  : 'no'
              }
            >

              {
                r.referable
                  ? 'YES'
                  : 'NO'
              }

            </b>

          </div>

        </div>

      </div>


      {/* VISUAL OUTPUTS */}

      <div className="visual-grid">

        <Visual
          title="Preprocessed fundus"
          src={r.artifacts?.preprocessed}
        />


        <Visual
          title="Grad-CAM explanation"
          src={
            r.artifacts?.gradcamOverlay
          }
          note="Regions most influential to the prediction"
        />


        <Visual
          title="Lesion candidate cues"
          src={
            r.artifacts?.lesionOverlay
          }
          note="Classical heuristic · supporting evidence"
        />

      </div>


      {/* EVIDENCE */}

      <div className="evidence-card">

        <div>

          <div className="card-title">
            Evidence report
          </div>


          <h3>
            What the pipeline found
          </h3>


          <div className="cue-grid">

            <div>

              <strong>

                {
                  r.lesionEvidence
                    ?.exudateCount ?? 0
                }

              </strong>

              <span>
                Bright candidates
              </span>

            </div>


            <div>

              <strong>

                {
                  r.lesionEvidence
                    ?.darkLesionCount ?? 0
                }

              </strong>

              <span>
                Dark candidates
              </span>

            </div>

          </div>

        </div>


        <div className="evidence-copy">

          <p>
            {r.evidenceText}
          </p>


          <div className="disclaimer">

            <Info size={15} />

            <span>

              Lesion counts are heuristic
              image-processing cues, not a
              trained segmentation model and
              not a diagnosis.

            </span>

          </div>

        </div>

      </div>

    </section>
  );
}


// ============================================================
// VISUAL
// ============================================================

function Visual({
  title,
  src,
  note
}) {

  return (

    <div className="visual-card">

      <div className="card-title">
        {title}
      </div>


      {src ? (

        <img
          src={
            backendPath(src) +
            '?t=' +
            Date.now()
          }
          alt={title}
        />

      ) : (

        <div className="image-placeholder">
          Waiting for artifact
        </div>

      )}


      <p>

        {
          note ||
          'Standardized image passed to the model.'
        }

      </p>

    </div>

  );
}


// ============================================================
// METHODOLOGY
// ============================================================

function Method() {

  const steps = [

    [
      '01',
      'QUALITY GATE',
      'Checks focus, illumination and field of view.'
    ],

    [
      '02',
      'PREPROCESS',
      'Crops retinal FOV, applies CLAHE, denoises and resizes to 224×224.'
    ],

    [
      '03',
      'DR GRADING',
      'Transfer-learned CNN predicts one of five ICDR grades.'
    ],

    [
      '04',
      'EXPLAIN',
      'Calibrates confidence, creates Grad-CAM and adds heuristic lesion cues.'
    ]

  ];


  return (

    <section
      id="method"
      className="section shell"
    >

      <div className="section-heading">

        <div>

          <div className="kicker">
            03 / METHODOLOGY
          </div>

          <h2>
            One pipeline. Four layers of evidence.
          </h2>

        </div>


        <p>

          Your MATLAB implementation remains
          the source of truth; the web layer
          visualizes its outputs.

        </p>

      </div>


      <div className="steps">

        {steps.map(s => (

          <div
            className="step"
            key={s[0]}
          >

            <span>
              {s[0]}
            </span>

            <h3>
              {s[1]}
            </h3>

            <p>
              {s[2]}
            </p>

          </div>

        ))}

      </div>

    </section>

  );
}


// ============================================================
// EVALUATION
// ============================================================

function Evaluation({
  data,
  onRefresh
}) {

  return (

    <section
      id="evaluation"
      className="section shell"
    >

      <div className="section-heading">

        <div>

          <div className="kicker">
            04 / MODEL EVALUATION
          </div>

          <h2>
            Performance dashboard
          </h2>

        </div>


        {/* <button
          className="ghost"
          onClick={onRefresh}
        >

          <RefreshCw size={14} />

          Refresh metrics

        </button> */}

      </div>


      {data ? (

        <>

          <div className="metric-strip">

            <div>

              <span>
                Referable DR sensitivity
              </span>

              <strong>

                {
                  (
                    Number(
                      data.sensitivity
                    ) * 100
                  ).toFixed(1)
                }%

              </strong>

              <small>
                Target &gt; 90%
              </small>

            </div>


            <div>

              <span>
                Referable DR specificity
              </span>

              <strong>

                {
                  (
                    Number(
                      data.specificity
                    ) * 100
                  ).toFixed(1)
                }%

              </strong>

              <small>
                Target &gt; 85%
              </small>

            </div>

          </div>


          <div className="table-wrap">

            <table>

              <thead>

                <tr>

                  <th>
                    Class
                  </th>

                  <th>
                    PPV
                  </th>

                  <th>
                    F1
                  </th>

                  <th>
                    Accuracy
                  </th>

                  <th>
                    AUC
                  </th>

                </tr>

              </thead>


              <tbody>

                {(
                  Array.isArray(
                    data.perClass
                  )
                    ? data.perClass
                    : [data.perClass]
                )
                  .filter(Boolean)
                  .map(x => (

                    <tr
                      key={x.ClassName}
                    >

                      <td>
                        {x.ClassName}
                      </td>

                      <td>
                        {fmt(x.PPV)}
                      </td>

                      <td>
                        {fmt(x.F1Score)}
                      </td>

                      <td>
                        {fmt(x.Accuracy)}
                      </td>

                      <td>
                        {fmt(x.AUC)}
                      </td>

                    </tr>

                  ))}

              </tbody>

            </table>

          </div>

        </>

      ) : (

        <div className="eval-empty">

          <FileText size={17} />

          <span>

            Evaluation metrics will appear here
            when <code>evaluationResults.mat</code>
            is available and the MATLAB bridge
            can export it.

          </span>

        </div>

      )}

    </section>

  );
}


// ============================================================
// FORMAT
// ============================================================

function fmt(v) {

  return (
    Number(v) * 100
  ).toFixed(1) + '%';

}


// ============================================================
// NAV
// ============================================================

function Nav({
  health
}) {

  return (

    <header className="nav shell">

      <a
        className="brand"
        href="#"
      >

        <span className="brand-mark">

          <i />
          <i />
          <i />

        </span>


        <span>

          DR<span>-</span>xAI

        </span>

      </a>


      <nav>

        <a href="#screen">
          Screening
        </a>

        <a href="#method">
          Methodology
        </a>

        <a href="#evaluation">
          Evaluation
        </a>

      </nav>


      <span className="nav-status">

        <i
          className={
            health?.matlabIntegration
              ? 'live'
              : ''
          }
        />


        {
          health?.matlabIntegration
            ? 'System ready'
            : 'Setup required'
        }

      </span>

    </header>

  );
}


// ============================================================
// FOOTER
// ============================================================

function Footer() {

  return (

    <footer>

      <div className="footer-brand">

        <span className="brand-mark">

          <i />
          <i />
          <i />

        </span>


        <b>
          DR-xAI
        </b>

      </div>


      <span>

        Explainable diabetic retinopathy
        screening 

      </span>


      <strong>
        Developed by Team Alphabet.
      </strong>

    </footer>

  );
}