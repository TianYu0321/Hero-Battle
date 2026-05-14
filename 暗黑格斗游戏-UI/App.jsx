/**
 * 暗黑格斗游戏 UI — PVP 对战大厅
 * 画布锁定 1920×1080
 * 顶部 HUD：左右对称（角色 + 血条 + 能量），中央竖向徽章塔（TIME / VS / ROUND）
 */

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "redHpPct": 78,
  "blueHpPct": 64,
  "roundNo": 7,
  "matchTime": "00:42",
  "accentGold": "oklch(0.82 0.16 78)"
}/*EDITMODE-END*/;

const FONT_LINK = "https://fonts.googleapis.com/css2?family=Cinzel:wght@600;800&family=Oxanium:wght@500;700;800&family=Noto+Sans+SC:wght@400;500;700;900&display=swap";

/* ---------------------------- HUD components ---------------------------- */

function PortraitTile({ side, rank }) {
  const flip = side === "blue";
  return (
    <div className={`portrait ${side}`}>
      <div className="portrait-frame">
        <svg className="portrait-art" viewBox="0 0 120 140" aria-hidden="true">
          <defs>
            <linearGradient id={`pgrad-${side}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={side === "red" ? "#ff5a4d" : "#4dc8ff"} />
              <stop offset="100%" stopColor={side === "red" ? "#3a060a" : "#06223a"} />
            </linearGradient>
            <pattern id={`pscan-${side}`} width="3" height="3" patternUnits="userSpaceOnUse">
              <rect width="3" height="1" fill="rgba(0,0,0,0.35)" />
            </pattern>
          </defs>
          <rect width="120" height="140" fill={`url(#pgrad-${side})`} />
          <rect width="120" height="140" fill={`url(#pscan-${side})`} />
          <g transform={flip ? "translate(120,0) scale(-1,1)" : ""} opacity="0.92">
            <path
              d="M60 28 L72 40 L70 56 L80 62 L86 84 L78 96 L82 122 L68 132 L58 110 L48 132 L36 122 L42 96 L34 84 L40 62 L50 56 L48 40 Z"
              fill="rgba(8,4,12,0.78)"
              stroke="rgba(255,255,255,0.18)"
              strokeWidth="0.6"
            />
            <circle cx="60" cy="34" r="7" fill="rgba(8,4,12,0.85)" stroke="rgba(255,255,255,0.18)" strokeWidth="0.6" />
            <path d="M44 60 L60 70 L76 60" stroke={side === "red" ? "#ffb4a3" : "#a3e0ff"} strokeWidth="1.4" fill="none" opacity="0.8" />
            <path d="M30 80 L20 76 M90 80 L100 76" stroke="rgba(255,255,255,0.25)" strokeWidth="0.8" />
          </g>
        </svg>
        <div className="portrait-rank">{rank}</div>
        <div className={`portrait-pulse ${side}`} />
      </div>
    </div>
  );
}

function HpBar({ side, pct, max = 1240 }) {
  const safe = Math.max(0, Math.min(100, pct));
  const isLow = safe < 30;
  const flip = side === "blue";
  const current = Math.round((safe / 100) * max);
  return (
    <div className={`hpwrap ${flip ? "flip" : ""}`}>
      <div className="hpframe">
        <div className="hpfill-bg" />
        <div className={`hpfill ${isLow ? "low" : ""}`} style={{ width: `${safe}%` }} />
        <div className="hp-seg" aria-hidden="true">
          {Array.from({ length: 20 }).map((_, i) => <span key={i} />)}
        </div>
        <div className="hp-shine" aria-hidden="true" />
      </div>
      <div className="hpmeta">
        <span className="hp-tag">HP</span>
        <span className="hp-num">{current}</span>
        <span className="hp-slash">/</span>
        <span className="hp-max">{max}</span>
      </div>
    </div>
  );
}

function EnergyBar({ side, pct = 60 }) {
  const flip = side === "blue";
  return (
    <div className={`enwrap ${flip ? "flip" : ""}`}>
      <span className="en-label">EN</span>
      <div className="enframe">
        <div className="enfill" style={{ width: `${pct}%` }} />
        <div className="en-ticks" aria-hidden="true">
          {Array.from({ length: 4 }).map((_, i) => <span key={i} />)}
        </div>
      </div>
      <span className="en-val">{pct}%</span>
    </div>
  );
}

function FighterCard({ side, name, sub, hp, en, rank }) {
  return (
    <div className={`fighter-card ${side}`}>
      {side === "red" && <PortraitTile side="red" rank={rank} />}
      <div className={`fighter-meta ${side}`}>
        <div className="meta-name-row">
          <span className="meta-name">{name}</span>
          <span className="meta-rank">{rank}</span>
        </div>
        <div className="meta-sub">{sub}</div>
        <HpBar side={side} pct={hp} />
        <EnergyBar side={side} pct={en} />
      </div>
      {side === "blue" && <PortraitTile side="blue" rank={rank} />}
    </div>
  );
}

/* --------------------------- Center HUD tower --------------------------- */

function CenterTower({ time, round, total = 12, stageName }) {
  return (
    <div className="tower">
      {/* Top: TIME ribbon */}
      <div className="tower-row time-row">
        <span className="ornament" />
        <span className="time-cluster">
          <span className="time-dot" />
          <span className="time-label">TIME</span>
          <span className="time-num">{time}</span>
        </span>
        <span className="ornament" />
      </div>

      {/* Middle: BIG VS */}
      <div className="tower-row vs-row">
        <span className="vs-wing left" aria-hidden="true">
          <svg viewBox="0 0 80 16">
            <path d="M0 8 L60 8 L72 4 M0 8 L60 8 L72 12" stroke="currentColor" strokeWidth="1.5" fill="none" />
          </svg>
        </span>
        <div className="vs-mark">
          <div className="vs-glow" aria-hidden="true" />
          <svg viewBox="0 0 220 130" aria-hidden="true">
            <defs>
              <linearGradient id="vsgrad" x1="0" y1="0" x2="1" y2="0">
                <stop offset="0%" stopColor="#ff3b56" />
                <stop offset="50%" stopColor="#ffd166" />
                <stop offset="100%" stopColor="#3dd4ff" />
              </linearGradient>
              <filter id="vsglow" x="-20%" y="-20%" width="140%" height="140%">
                <feGaussianBlur stdDeviation="2" />
              </filter>
            </defs>
            {/* Background slashes */}
            <path d="M14 110 L94 14" stroke="rgba(255,80,90,0.35)" strokeWidth="2" />
            <path d="M126 14 L206 110" stroke="rgba(60,180,255,0.35)" strokeWidth="2" />
            <text
              x="110" y="92"
              textAnchor="middle"
              fontFamily="Cinzel, serif"
              fontWeight="800"
              fontSize="96"
              letterSpacing="6"
              fill="url(#vsgrad)"
              stroke="rgba(0,0,0,0.7)"
              strokeWidth="2.2"
              paintOrder="stroke"
            >VS</text>
          </svg>
          <span className="vs-spark a" />
          <span className="vs-spark b" />
        </div>
        <span className="vs-wing right" aria-hidden="true">
          <svg viewBox="0 0 80 16">
            <path d="M80 8 L20 8 L8 4 M80 8 L20 8 L8 12" stroke="currentColor" strokeWidth="1.5" fill="none" />
          </svg>
        </span>
      </div>

      {/* Round badge */}
      <div className="tower-row round-row">
        <div className="round-badge">
          <svg className="round-ring" viewBox="0 0 96 96" aria-hidden="true">
            <defs>
              <linearGradient id="ringg" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="var(--gold)" />
                <stop offset="50%" stopColor="#7a5a18" />
                <stop offset="100%" stopColor="var(--gold)" />
              </linearGradient>
            </defs>
            <polygon points="48,3 93,48 48,93 3,48" fill="none" stroke="url(#ringg)" strokeWidth="1.6" />
            <polygon points="48,11 85,48 48,85 11,48" fill="rgba(10,4,18,0.85)" stroke="rgba(255,200,100,0.4)" strokeWidth="0.6" />
          </svg>
          <div className="round-text">
            <span className="round-kanji">ROUND</span>
            <span className="round-num">
              {String(round).padStart(2, "0")}
              <span className="round-total"> / {String(total).padStart(2, "0")}</span>
            </span>
          </div>
        </div>
      </div>

      {/* Stage name */}
      <div className="tower-row stage-row">
        <span className="stage-line" />
        <span className="stage-name">{stageName}</span>
        <span className="stage-line" />
      </div>
    </div>
  );
}

/* ----------------------------- Combat log ----------------------------- */

const LOG_ENTRIES = [
  { t: "00:42", who: "red", text: "AI_斗技者_Y1 使出 「裂魂斩」, 命中玩家镜像", dmg: 184, kind: "crit" },
  { t: "00:39", who: "blue", text: "玩家镜像 触发被动 「逆鳞」, 反弹 32% 伤害", dmg: 58, kind: "buff" },
  { t: "00:35", who: "red", text: "AI_斗技者_Y1 → 玩家镜像 普通连击 ×3", dmg: 96, kind: "hit" },
  { t: "00:31", who: "sys", text: "回合 06 结束 · 双方进入硬直评估", dmg: null, kind: "sys" },
  { t: "00:28", who: "blue", text: "玩家镜像 使出 「碎星拳」 暴击!", dmg: 211, kind: "crit" },
  { t: "00:24", who: "red", text: "AI_斗技者_Y1 格挡 35%, 受到残余冲击", dmg: 44, kind: "block" },
  { t: "00:20", who: "sys", text: "环境效果 「腐蚀雾」 触发, 双方持续掉血", dmg: 12, kind: "sys" },
  { t: "00:16", who: "blue", text: "玩家镜像 → AI_斗技者_Y1 突进取消", dmg: null, kind: "hit" },
  { t: "00:11", who: "red", text: "AI_斗技者_Y1 蓄力中 · 蓄爆条 78%", dmg: null, kind: "buff" },
  { t: "00:07", who: "blue", text: "玩家镜像 触发连段 「碎月·终式」", dmg: 168, kind: "crit" },
];

function LogPanel() {
  return (
    <section className="logpanel" aria-label="战斗日志">
      <header className="log-head">
        <div className="log-title">
          <span className="log-dot" />
          <span className="log-zh">战 斗 日 志</span>
          <span className="log-en">COMBAT LOG · LIVE</span>
        </div>
        <div className="log-tabs">
          <button className="tab active" type="button">全部</button>
          <button className="tab" type="button">伤害</button>
          <button className="tab" type="button">技能</button>
          <button className="tab" type="button">系统</button>
        </div>
      </header>
      <ol className="log-list">
        {LOG_ENTRIES.map((e, i) => (
          <li key={i} className={`log-row ${e.who} ${e.kind}`}>
            <span className="log-t">{e.t}</span>
            <span className={`log-side ${e.who}`}>
              {e.who === "red" ? "R1" : e.who === "blue" ? "B2" : "SYS"}
            </span>
            <span className="log-text">{e.text}</span>
            {e.dmg !== null && (
              <span className={`log-dmg ${e.kind}`}>
                {e.kind === "buff" ? "+" : "-"}{e.dmg}
              </span>
            )}
          </li>
        ))}
      </ol>
      <div className="log-actions">
        <button className="act primary" type="button">
          <span className="act-key">A</span>
          <span className="act-label">攻击</span>
        </button>
        <button className="act" type="button">
          <span className="act-key">S</span>
          <span className="act-label">防御</span>
        </button>
        <button className="act" type="button">
          <span className="act-key">D</span>
          <span className="act-label">技能</span>
        </button>
        <button className="act warn" type="button">
          <span className="act-key">⎵</span>
          <span className="act-label">跳过回合</span>
        </button>
      </div>
    </section>
  );
}

/* ----------------------------- Stage art ----------------------------- */

function FighterArt({ side }) {
  const flip = side === "blue";
  const main = side === "red" ? "#ff3b48" : "#2cb6ff";
  const dark = side === "red" ? "#3b060a" : "#062436";
  const glow = side === "red" ? "#ff6357" : "#5ad2ff";
  return (
    <svg className="fighter-svg" viewBox="0 0 220 320" aria-hidden="true">
      <defs>
        <linearGradient id={`fbody-${side}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={main} />
          <stop offset="100%" stopColor={dark} />
        </linearGradient>
        <filter id={`fglow-${side}`} x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="6" result="b" />
          <feMerge>
            <feMergeNode in="b" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>
      <g transform={flip ? "translate(220,0) scale(-1,1)" : ""}>
        <path d="M70 90 Q40 160 50 260 L70 230 L78 110 Z" fill={dark} opacity="0.85" />
        <path
          d="M110 50 L138 70 L134 110 L160 138 L150 200 L160 248 L138 304 L120 268 L110 240 L100 268 L82 304 L60 248 L70 200 L60 138 L86 110 L82 70 Z"
          fill={`url(#fbody-${side})`}
          stroke="rgba(255,255,255,0.18)"
          strokeWidth="1.2"
          filter={`url(#fglow-${side})`}
        />
        <path d="M110 22 L132 36 L130 58 L120 64 L100 64 L90 58 L88 36 Z" fill={dark} stroke={main} strokeWidth="1.6" />
        <path d="M92 50 L128 50" stroke={glow} strokeWidth="2" opacity="0.9" />
        <circle cx="102" cy="48" r="2" fill={glow} />
        <circle cx="118" cy="48" r="2" fill={glow} />
        <g opacity="0.95">
          <path d="M150 120 L210 60 L218 68 L158 128 Z" fill="rgba(220,220,235,0.85)" stroke="rgba(0,0,0,0.5)" strokeWidth="0.8" />
          <rect x="140" y="120" width="22" height="8" fill={dark} stroke={main} />
        </g>
        <path d="M100 130 L110 120 L120 130 L110 142 Z" fill="none" stroke={glow} strokeWidth="1.4" />
        <circle cx="110" cy="131" r="2" fill={glow} />
        <rect x="78" y="196" width="64" height="10" fill={dark} stroke={main} strokeWidth="0.8" />
        <path d="M86 220 L100 240 M134 220 L120 240" stroke={glow} strokeWidth="1.2" opacity="0.7" />
      </g>
    </svg>
  );
}

function StageInfo({ round, total = 12 }) {
  return (
    <div className="stage-info">
      <div className="info-eyebrow">PVP · 对 战 大 厅</div>
      <h1 className="info-title">勇 者 试 炼 · 第 七 关</h1>
      <div className="info-meta">
        <div className="meta-row">
          <span className="meta-k">出战</span>
          <span className="meta-v">勇者 <em>A 级</em></span>
        </div>
        <div className="meta-row">
          <span className="meta-k">净胜场</span>
          <span className="meta-v gold">3 连胜</span>
        </div>
        <div className="meta-row">
          <span className="meta-k">回合</span>
          <span className="meta-v">{String(round).padStart(2, "0")} / {String(total).padStart(2, "0")}</span>
        </div>
      </div>
      <div className="info-divider">
        <span />
        <span className="diamond">◆</span>
        <span />
      </div>
      <div className="info-stats">
        <div className="stat">
          <span className="stat-k">总伤害</span>
          <span className="stat-v">2,184</span>
        </div>
        <div className="stat">
          <span className="stat-k">承伤</span>
          <span className="stat-v">1,520</span>
        </div>
        <div className="stat">
          <span className="stat-k">暴击率</span>
          <span className="stat-v">42%</span>
        </div>
      </div>
      <div className="info-cta">
        <button type="button" className="cta-ghost">查看排行</button>
        <button type="button" className="cta-fill">匹配下一位</button>
      </div>
    </div>
  );
}

/* --------------------------------- App --------------------------------- */

function App() {
  const t = TWEAK_DEFAULTS;
  return (
    <>
      <style>{`@import url("${FONT_LINK}");`}</style>
      <Styles />
      <main className="arena" role="main">
        <div className="bg-grid" aria-hidden="true" />
        <div className="bg-vignette" aria-hidden="true" />
        <div className="bg-noise" aria-hidden="true" />

        {/* ===== HUD ===== */}
        <header className="hud">
          <FighterCard
            side="red"
            name="AI_斗技者_Y1"
            sub="LV.42 · 暗影流派"
            rank="S"
            hp={t.redHpPct}
            en={82}
          />
          <CenterTower
            time={t.matchTime}
            round={t.roundNo}
            total={12}
            stageName="深 渊 斗 技 场"
          />
          <FighterCard
            side="blue"
            name="玩 家 镜 像"
            sub="LV.40 · 镜流派"
            rank="A"
            hp={t.blueHpPct}
            en={48}
          />
        </header>

        {/* ===== Stage ===== */}
        <section className="stage" aria-label="对战舞台">
          <div className="stage-floor" aria-hidden="true">
            <div className="floor-grid" />
            <div className="floor-glow red" />
            <div className="floor-glow blue" />
          </div>

          <div className="fighter red">
            <FighterArt side="red" />
            <div className="fighter-base" />
            <div className="fighter-tag">
              <span className="tag-arrow">◄</span>
              <span>AI_斗技者_Y1</span>
            </div>
            <div className="impact left" aria-hidden="true">
              <span className="spark s1" />
              <span className="spark s2" />
              <span className="impact-num">-184</span>
            </div>
          </div>

          <StageInfo round={t.roundNo} total={12} />

          <div className="fighter blue">
            <FighterArt side="blue" />
            <div className="fighter-base" />
            <div className="fighter-tag right">
              <span>玩家镜像</span>
              <span className="tag-arrow">►</span>
            </div>
          </div>
        </section>

        {/* ===== Combat Log ===== */}
        <LogPanel />
      </main>
    </>
  );
}

function Styles() {
  return (
    <style>{`
      :root {
        --bg-0: oklch(0.10 0.025 290);
        --bg-1: oklch(0.14 0.04 295);
        --bg-2: oklch(0.18 0.06 300);
        --ink-0: oklch(0.94 0.015 280);
        --ink-1: oklch(0.74 0.03 280);
        --ink-2: oklch(0.52 0.04 285);
        --line: oklch(0.32 0.04 290);
        --line-soft: oklch(0.24 0.03 290);
        --red: oklch(0.66 0.22 25);
        --red-bright: oklch(0.74 0.21 30);
        --red-deep: oklch(0.32 0.14 22);
        --blue: oklch(0.74 0.16 230);
        --blue-bright: oklch(0.82 0.16 225);
        --blue-deep: oklch(0.30 0.10 240);
        --gold: var(--ocd-tweak-accent-gold, oklch(0.82 0.16 78));
        --gold-dim: oklch(0.55 0.12 75);
        --crit: oklch(0.88 0.18 70);
        --shadow-sharp: 0 1px 0 rgba(255,255,255,0.06), 0 14px 32px rgba(0,0,0,0.55);
      }

      *, *::before, *::after { box-sizing: border-box; }
      html, body {
        margin: 0; padding: 0;
        background: #06030c;
        min-height: 100%;
      }
      body {
        font-family: "Oxanium", "Noto Sans SC", "PingFang SC", system-ui, sans-serif;
        color: var(--ink-0);
        -webkit-font-smoothing: antialiased;
        display: flex;
        justify-content: center;
        align-items: flex-start;
        overflow: auto;
      }
      button { font-family: inherit; }

      /* ========== Canvas: locked 1920×1080 ========== */
      .arena {
        position: relative;
        width: 1920px;
        height: 1080px;
        flex-shrink: 0;
        display: grid;
        grid-template-rows: 240px 1fr 320px;
        background:
          radial-gradient(120% 80% at 50% -10%, rgba(120,30,60,0.35), transparent 55%),
          radial-gradient(80% 60% at 8% 110%, rgba(40,10,90,0.45), transparent 60%),
          radial-gradient(80% 60% at 92% 110%, rgba(10,40,90,0.4), transparent 60%),
          linear-gradient(180deg, #0a0612 0%, #06030c 60%, #03020a 100%);
        overflow: hidden;
        isolation: isolate;
      }

      .bg-grid {
        position: absolute; inset: 0;
        background-image:
          linear-gradient(rgba(255,255,255,0.035) 1px, transparent 1px),
          linear-gradient(90deg, rgba(255,255,255,0.035) 1px, transparent 1px);
        background-size: 64px 64px;
        mask-image: radial-gradient(80% 60% at 50% 70%, black 30%, transparent 80%);
        pointer-events: none;
        z-index: 0;
      }
      .bg-vignette {
        position: absolute; inset: 0;
        background: radial-gradient(120% 80% at 50% 50%, transparent 40%, rgba(0,0,0,0.78) 100%);
        pointer-events: none; z-index: 0;
      }
      .bg-noise {
        position: absolute; inset: 0;
        background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.6 0'/></filter><rect width='100%' height='100%' filter='url(%23n)' opacity='0.6'/></svg>");
        opacity: 0.18; pointer-events: none; mix-blend-mode: overlay; z-index: 0;
      }

      /* ============================== HUD ============================== */
      .hud {
        position: relative; z-index: 3;
        display: grid;
        grid-template-columns: 1fr 560px 1fr;
        align-items: center;
        gap: 40px;
        padding: 24px 64px 18px;
        border-bottom: 1px solid var(--line-soft);
        background:
          linear-gradient(180deg, rgba(8,4,16,0.92), rgba(8,4,16,0.55) 70%, transparent),
          linear-gradient(90deg, rgba(140,20,30,0.22), transparent 22%, transparent 78%, rgba(20,80,140,0.22));
      }

      /* ----- Fighter card (symmetric) ----- */
      .fighter-card {
        display: grid;
        align-items: center;
        gap: 22px;
        min-width: 0;
      }
      .fighter-card.red {
        grid-template-columns: 132px minmax(0, 1fr);
      }
      .fighter-card.blue {
        grid-template-columns: minmax(0, 1fr) 132px;
      }
      .fighter-meta {
        display: flex;
        flex-direction: column;
        gap: 8px;
        min-width: 0;
      }
      .fighter-meta.blue { text-align: right; }

      .meta-name-row {
        display: flex;
        align-items: baseline;
        gap: 12px;
        font-family: "Cinzel", "Noto Serif SC", serif;
      }
      .fighter-meta.blue .meta-name-row { justify-content: flex-end; flex-direction: row-reverse; }
      .meta-name {
        font-size: 22px;
        font-weight: 800;
        letter-spacing: 0.06em;
        color: var(--ink-0);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }
      .fighter-card.red .meta-name { text-shadow: 0 0 14px rgba(255,80,100,0.28); }
      .fighter-card.blue .meta-name { text-shadow: 0 0 14px rgba(80,180,255,0.28); }
      .meta-rank {
        font-family: "Cinzel", serif;
        font-size: 18px; font-weight: 800;
        color: var(--gold);
        padding: 0 10px;
        border: 1px solid var(--gold-dim);
        clip-path: polygon(6px 0, 100% 0, calc(100% - 6px) 100%, 0 100%);
        background: rgba(255,200,80,0.06);
      }
      .meta-sub {
        font-family: "Oxanium", sans-serif;
        font-size: 12px;
        letter-spacing: 0.22em;
        color: var(--ink-2);
        text-transform: uppercase;
      }

      /* ----- Portrait tile (identical size both sides) ----- */
      .portrait {
        width: 132px; height: 152px;
        display: flex; align-items: center; justify-content: center;
      }
      .portrait-frame {
        position: relative;
        width: 100%; height: 100%;
        background: #0a040c;
        border: 1px solid var(--line);
        overflow: hidden;
      }
      .portrait.red .portrait-frame {
        clip-path: polygon(14px 0, 100% 0, calc(100% - 14px) 100%, 0 100%);
        box-shadow: inset 0 0 24px rgba(255,40,60,0.25), 0 0 0 1px rgba(255,80,90,0.18);
      }
      .portrait.blue .portrait-frame {
        clip-path: polygon(0 0, calc(100% - 14px) 0, 100% 100%, 14px 100%);
        box-shadow: inset 0 0 24px rgba(60,160,255,0.25), 0 0 0 1px rgba(80,180,255,0.18);
      }
      .portrait-art { position: absolute; inset: 0; width: 100%; height: 100%; }
      .portrait-pulse {
        position: absolute; inset: 0;
        animation: pulse 2.4s ease-in-out infinite;
        pointer-events: none;
      }
      .portrait-pulse.red { box-shadow: inset 0 0 22px rgba(255,40,60,0.5); }
      .portrait-pulse.blue { box-shadow: inset 0 0 22px rgba(50,160,255,0.5); }
      @keyframes pulse {
        0%, 100% { opacity: 0.7; }
        50% { opacity: 1; }
      }
      .portrait-rank {
        position: absolute; top: 6px; right: 8px;
        font-family: "Cinzel", serif;
        font-size: 18px; font-weight: 800;
        color: var(--gold);
        text-shadow: 0 0 8px rgba(255,200,80,0.65), 0 1px 0 rgba(0,0,0,0.6);
      }
      .portrait.blue .portrait-rank { left: 8px; right: auto; }

      /* ----- HP bar ----- */
      .hpwrap { position: relative; }
      .hpframe {
        position: relative; height: 28px;
        background: linear-gradient(180deg, #1a0a16, #0a040c);
        border: 1px solid rgba(255,255,255,0.08);
        clip-path: polygon(14px 0, 100% 0, calc(100% - 14px) 100%, 0 100%);
        box-shadow:
          inset 0 1px 0 rgba(255,255,255,0.08),
          inset 0 -2px 0 rgba(0,0,0,0.6),
          0 0 20px rgba(255,40,60,0.18);
        overflow: hidden;
      }
      .hpwrap.flip .hpframe {
        clip-path: polygon(0 0, calc(100% - 14px) 0, 100% 100%, 14px 100%);
        box-shadow:
          inset 0 1px 0 rgba(255,255,255,0.08),
          inset 0 -2px 0 rgba(0,0,0,0.6),
          0 0 20px rgba(40,160,255,0.2);
      }
      .hpfill-bg {
        position: absolute; inset: 0;
        background: linear-gradient(180deg, rgba(80,10,30,0.5), rgba(20,4,10,0.3));
      }
      .hpfill {
        position: absolute; top: 0; bottom: 0; left: 0;
        background: linear-gradient(180deg, #ff6a4a 0%, #ff2b3a 45%, #b91030 100%);
        box-shadow:
          inset 0 1px 0 rgba(255,255,255,0.45),
          inset 0 -3px 0 rgba(0,0,0,0.35),
          0 0 14px rgba(255,60,80,0.55);
        transition: width 320ms cubic-bezier(.2,.7,.2,1);
      }
      .hpwrap.flip .hpfill {
        left: auto; right: 0;
        background: linear-gradient(180deg, #67e1ff 0%, #1f9eff 45%, #0a4fb0 100%);
        box-shadow:
          inset 0 1px 0 rgba(255,255,255,0.45),
          inset 0 -3px 0 rgba(0,0,0,0.35),
          0 0 14px rgba(60,160,255,0.55);
      }
      .hpfill.low {
        background: linear-gradient(180deg, #ffd166 0%, #ff5a3c 60%, #7a0e1c 100%);
        animation: hpblink 0.9s ease-in-out infinite;
      }
      @keyframes hpblink {
        50% { filter: brightness(1.25) saturate(1.2); }
      }
      .hp-seg {
        position: absolute; inset: 0;
        display: flex; pointer-events: none;
      }
      .hp-seg span {
        flex: 1;
        border-right: 1px solid rgba(0,0,0,0.5);
        box-shadow: inset -1px 0 0 rgba(255,255,255,0.05);
      }
      .hp-seg span:last-child { border-right: 0; }
      .hp-shine {
        position: absolute; top: 2px; left: 14px; right: 14px; height: 5px;
        background: linear-gradient(180deg, rgba(255,255,255,0.35), rgba(255,255,255,0));
        border-radius: 2px; pointer-events: none;
      }
      .hpmeta {
        margin-top: 6px;
        display: flex; align-items: baseline; gap: 6px;
        font-family: "Oxanium", monospace;
        font-size: 13px; color: var(--ink-1);
      }
      .hpwrap.flip .hpmeta { justify-content: flex-end; flex-direction: row-reverse; }
      .hp-num { color: var(--ink-0); font-weight: 800; font-size: 16px; }
      .hp-slash { color: var(--ink-2); }
      .hp-max { color: var(--ink-2); }
      .hp-tag {
        padding: 2px 8px;
        border: 1px solid var(--line);
        color: var(--ink-1);
        font-size: 11px; letter-spacing: 0.22em;
        font-weight: 700;
      }

      /* ----- Energy bar ----- */
      .enwrap {
        display: flex; align-items: center; gap: 10px;
        font-family: "Oxanium", monospace;
      }
      .enwrap.flip { flex-direction: row-reverse; }
      .enframe {
        position: relative; flex: 1; height: 8px;
        background: rgba(255,255,255,0.05);
        border: 1px solid rgba(255,255,255,0.1);
      }
      .enfill {
        position: absolute; top: 0; bottom: 0; left: 0;
        background: linear-gradient(90deg, var(--gold) 0%, #fff3b8 50%, var(--gold) 100%);
        box-shadow: 0 0 12px rgba(255,200,80,0.55);
      }
      .enwrap.flip .enfill { left: auto; right: 0; }
      .en-ticks {
        position: absolute; inset: 0;
        display: flex; pointer-events: none;
      }
      .en-ticks span {
        flex: 1; border-right: 1px solid rgba(0,0,0,0.6);
      }
      .en-ticks span:last-child { border-right: 0; }
      .en-label {
        font-size: 11px; letter-spacing: 0.28em;
        color: var(--gold-dim); font-weight: 700;
      }
      .en-val {
        font-size: 12px; color: var(--ink-1); font-weight: 700;
        min-width: 36px; text-align: right;
      }
      .enwrap.flip .en-val { text-align: left; }

      /* ============================== Center Tower ============================== */
      .tower {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 6px;
        padding: 4px 0;
      }
      .tower-row {
        display: flex; align-items: center; justify-content: center;
        width: 100%;
      }

      .time-row { gap: 14px; }
      .ornament {
        flex: 1; height: 1px;
        background: linear-gradient(90deg, transparent, var(--gold-dim) 30%, var(--gold-dim) 70%, transparent);
        opacity: 0.6;
        max-width: 160px;
      }
      .time-cluster {
        display: flex; align-items: center; gap: 10px;
        padding: 4px 14px;
        border: 1px solid var(--line);
        background: rgba(10,4,18,0.65);
        clip-path: polygon(8px 0, calc(100% - 8px) 0, 100% 100%, 0 100%);
      }
      .time-dot {
        width: 7px; height: 7px; border-radius: 50%;
        background: var(--red-bright);
        box-shadow: 0 0 10px var(--red-bright);
        animation: blink 1.1s ease-in-out infinite;
      }
      @keyframes blink { 50% { opacity: 0.3; } }
      .time-label {
        font-family: "Oxanium", sans-serif;
        font-size: 11px; font-weight: 800; letter-spacing: 0.32em;
        color: var(--gold-dim);
      }
      .time-num {
        font-family: "Oxanium", monospace;
        font-size: 18px; font-weight: 800; letter-spacing: 0.12em;
        color: var(--ink-0);
        text-shadow: 0 0 8px rgba(255,255,255,0.18);
      }

      .vs-row {
        gap: 18px;
        margin-top: 2px;
      }
      .vs-wing {
        display: flex; align-items: center;
        width: 80px; height: 16px;
        color: var(--gold-dim);
        flex-shrink: 0;
      }
      .vs-wing svg { width: 100%; height: 100%; }
      .vs-mark {
        position: relative;
        width: 240px; height: 130px;
        display: flex; align-items: center; justify-content: center;
        flex-shrink: 0;
      }
      .vs-mark svg { width: 100%; height: 100%; position: relative; z-index: 2; }
      .vs-glow {
        position: absolute; inset: -12px;
        background:
          radial-gradient(60% 70% at 50% 50%, rgba(255,180,80,0.28), transparent 70%),
          radial-gradient(80% 80% at 22% 60%, rgba(255,60,90,0.35), transparent 70%),
          radial-gradient(80% 80% at 78% 60%, rgba(60,180,255,0.35), transparent 70%);
        filter: blur(10px);
        z-index: 1;
        animation: vsPulse 2.8s ease-in-out infinite;
      }
      @keyframes vsPulse {
        0%, 100% { opacity: 0.6; transform: scale(0.96); }
        50% { opacity: 1; transform: scale(1.04); }
      }
      .vs-spark {
        position: absolute;
        width: 2px; height: 22px;
        background: linear-gradient(180deg, transparent, var(--gold), transparent);
        opacity: 0.9; z-index: 3;
      }
      .vs-spark.a { top: -6px; left: 48px; transform: rotate(-14deg); }
      .vs-spark.b { bottom: -6px; right: 50px; transform: rotate(16deg); }

      .round-row { margin-top: 4px; }
      .round-badge {
        position: relative;
        width: 110px; height: 110px;
        display: flex; align-items: center; justify-content: center;
      }
      .round-ring {
        position: absolute; inset: 0;
        width: 100%; height: 100%;
        animation: rotate 16s linear infinite;
      }
      @keyframes rotate { to { transform: rotate(360deg); } }
      .round-text {
        position: relative; z-index: 2;
        display: flex; flex-direction: column; align-items: center;
        line-height: 1;
        gap: 4px;
      }
      .round-kanji {
        font-family: "Cinzel", serif;
        font-size: 10px; letter-spacing: 0.42em;
        color: var(--gold);
        text-shadow: 0 0 6px rgba(255,200,80,0.4);
      }
      .round-num {
        font-family: "Oxanium", monospace;
        font-size: 26px; font-weight: 800;
        color: var(--ink-0);
        text-shadow: 0 0 12px rgba(255,200,80,0.5);
      }
      .round-total {
        font-size: 12px; font-weight: 700; color: var(--gold-dim);
      }

      .stage-row { gap: 14px; margin-top: 2px; }
      .stage-line {
        flex: 1; height: 1px;
        background: linear-gradient(90deg, transparent, var(--line), transparent);
        max-width: 120px;
      }
      .stage-name {
        font-family: "Cinzel", "Noto Serif SC", serif;
        font-size: 12px;
        font-weight: 600;
        letter-spacing: 0.42em;
        color: var(--gold-dim);
        text-transform: uppercase;
        white-space: nowrap;
      }

      /* ============================== Stage ============================== */
      .stage {
        position: relative; z-index: 1;
        display: grid;
        grid-template-columns: 1fr 460px 1fr;
        align-items: end;
        padding: 32px 64px 24px;
        gap: 24px;
        min-height: 0;
      }
      .stage-floor {
        position: absolute; inset: auto 0 0 0; height: 75%;
        pointer-events: none;
      }
      .floor-grid {
        position: absolute; inset: auto 0 0 0; height: 60%;
        background-image:
          linear-gradient(rgba(180,140,240,0.12) 1px, transparent 1px),
          linear-gradient(90deg, rgba(180,140,240,0.12) 1px, transparent 1px);
        background-size: 80px 36px;
        transform: perspective(700px) rotateX(64deg);
        transform-origin: bottom;
        mask-image: linear-gradient(180deg, transparent 0%, black 30%, black 80%, transparent 100%);
      }
      .floor-glow {
        position: absolute; bottom: 0; width: 42%; height: 90%;
        filter: blur(50px); opacity: 0.65;
      }
      .floor-glow.red { left: 0; background: radial-gradient(60% 100% at 28% 100%, rgba(255,30,60,0.6), transparent 70%); }
      .floor-glow.blue { right: 0; background: radial-gradient(60% 100% at 72% 100%, rgba(40,140,255,0.6), transparent 70%); }

      .fighter {
        position: relative;
        display: flex; flex-direction: column; align-items: center;
        padding-bottom: 24px;
      }
      .fighter-svg {
        width: 100%; max-width: 360px; height: auto;
        filter: drop-shadow(0 22px 28px rgba(0,0,0,0.65));
      }
      .fighter.red .fighter-svg { transform: translateX(-2%); }
      .fighter.blue .fighter-svg { transform: translateX(2%); }
      .fighter-base {
        width: 70%; height: 22px;
        margin-top: -10px;
        border-radius: 50%;
        background: radial-gradient(50% 60% at 50% 50%, rgba(0,0,0,0.7), transparent 70%);
      }
      .fighter-tag {
        position: absolute; top: 12px; left: 12px;
        display: flex; align-items: center; gap: 8px;
        font-family: "Oxanium", monospace;
        font-size: 12px; letter-spacing: 0.22em;
        padding: 5px 10px;
        background: rgba(10,4,16,0.75);
        border: 1px solid var(--line);
        border-left: 2px solid var(--red-bright);
        color: var(--ink-1);
      }
      .fighter-tag.right {
        left: auto; right: 12px;
        border-left: 1px solid var(--line);
        border-right: 2px solid var(--blue-bright);
      }
      .tag-arrow { color: var(--red-bright); }
      .fighter-tag.right .tag-arrow { color: var(--blue-bright); }

      /* ----- Impact on red fighter ----- */
      .impact {
        position: absolute;
        top: 38%;
        pointer-events: none;
      }
      .impact.left { right: -20px; }
      .impact-num {
        font-family: "Cinzel", "Noto Serif SC", serif;
        font-weight: 800; font-size: 48px;
        color: var(--crit);
        text-shadow:
          0 0 24px rgba(255,200,80,0.78),
          0 2px 0 rgba(0,0,0,0.65),
          0 0 1px rgba(255,255,255,0.4);
        transform: rotate(-10deg);
        white-space: nowrap;
        animation: floatUp 2.4s ease-in-out infinite;
        display: inline-block;
      }
      @keyframes floatUp {
        0%, 100% { transform: rotate(-10deg) translateY(0); opacity: 0.95; }
        50% { transform: rotate(-10deg) translateY(-6px); opacity: 1; }
      }
      .spark {
        position: absolute; width: 16px; height: 16px; border-radius: 50%;
        background: radial-gradient(circle, #fff 0%, var(--gold) 30%, transparent 70%);
        filter: blur(0.4px);
      }
      .spark.s1 { left: -50px; top: 56px; }
      .spark.s2 { left: 60px; top: -22px; width: 9px; height: 9px; }

      /* ----- Stage info card ----- */
      .stage-info {
        align-self: center;
        padding: 26px 28px 22px;
        position: relative;
        background: linear-gradient(180deg, rgba(20,10,30,0.9), rgba(10,4,20,0.94));
        border: 1px solid var(--line);
        clip-path: polygon(16px 0, calc(100% - 16px) 0, 100% 16px, 100% calc(100% - 16px), calc(100% - 16px) 100%, 16px 100%, 0 calc(100% - 16px), 0 16px);
        box-shadow: var(--shadow-sharp), inset 0 1px 0 rgba(255,255,255,0.04);
      }
      .stage-info::before, .stage-info::after {
        content: "";
        position: absolute;
        width: 16px; height: 16px;
        border: 1px solid var(--gold);
      }
      .stage-info::before { top: -1px; left: -1px; border-right: 0; border-bottom: 0; }
      .stage-info::after { bottom: -1px; right: -1px; border-left: 0; border-top: 0; }
      .info-eyebrow {
        font-family: "Oxanium", sans-serif;
        font-size: 11px; letter-spacing: 0.5em; color: var(--gold);
        text-transform: uppercase;
      }
      .info-title {
        margin: 8px 0 16px;
        font-family: "Cinzel", "Noto Serif SC", serif;
        font-weight: 800;
        font-size: 26px;
        letter-spacing: 0.14em;
        color: var(--ink-0);
        text-shadow: 0 0 20px rgba(255,200,120,0.2);
      }
      .info-meta {
        display: flex; flex-direction: column; gap: 6px;
        padding: 12px 14px;
        border: 1px solid var(--line-soft);
        background: rgba(255,255,255,0.02);
      }
      .meta-row {
        display: flex; justify-content: space-between; align-items: baseline;
        font-size: 14px;
      }
      .meta-k { color: var(--ink-2); letter-spacing: 0.18em; font-size: 12px; }
      .meta-v { color: var(--ink-0); font-weight: 600; }
      .meta-v em { font-style: normal; color: var(--gold); padding-left: 4px; }
      .meta-v.gold { color: var(--gold); font-family: "Oxanium", monospace; }

      .info-divider {
        display: grid; grid-template-columns: 1fr auto 1fr;
        align-items: center; gap: 12px;
        margin: 16px 0 14px;
      }
      .info-divider span:first-child,
      .info-divider span:last-child {
        height: 1px; background: linear-gradient(90deg, transparent, var(--line), transparent);
      }
      .diamond { color: var(--gold); font-size: 13px; }

      .info-stats {
        display: grid; grid-template-columns: repeat(3, 1fr);
        gap: 1px;
        background: var(--line-soft);
        border: 1px solid var(--line-soft);
      }
      .stat {
        padding: 10px 12px;
        background: rgba(10,4,18,0.7);
        display: flex; flex-direction: column; gap: 2px;
      }
      .stat-k { font-size: 11px; letter-spacing: 0.22em; color: var(--ink-2); }
      .stat-v {
        font-family: "Oxanium", monospace;
        font-size: 19px; font-weight: 700; color: var(--ink-0);
      }
      .info-cta {
        margin-top: 16px;
        display: flex; gap: 10px;
      }
      .cta-ghost, .cta-fill {
        flex: 1; padding: 11px 12px;
        font-family: "Oxanium", "Noto Sans SC", sans-serif;
        font-size: 13px; font-weight: 700; letter-spacing: 0.2em;
        text-transform: uppercase;
        cursor: pointer;
        transition: transform 120ms ease, box-shadow 200ms ease, background 200ms ease;
      }
      .cta-ghost {
        background: transparent;
        color: var(--ink-1);
        border: 1px solid var(--line);
        clip-path: polygon(10px 0, 100% 0, calc(100% - 10px) 100%, 0 100%);
      }
      .cta-ghost:hover { color: var(--ink-0); border-color: var(--gold-dim); box-shadow: 0 0 18px rgba(255,200,80,0.18); }
      .cta-fill {
        background: linear-gradient(180deg, var(--red-bright), var(--red));
        color: #fff5f0;
        border: 1px solid rgba(255,180,150,0.4);
        clip-path: polygon(10px 0, 100% 0, calc(100% - 10px) 100%, 0 100%);
        box-shadow: 0 0 24px rgba(255,40,60,0.35), inset 0 1px 0 rgba(255,255,255,0.3);
        text-shadow: 0 1px 0 rgba(0,0,0,0.4);
      }
      .cta-fill:hover { transform: translateY(-1px); box-shadow: 0 0 32px rgba(255,40,60,0.55), inset 0 1px 0 rgba(255,255,255,0.4); }

      /* ============================== Log Panel ============================== */
      .logpanel {
        position: relative; z-index: 2;
        display: grid;
        grid-template-columns: 1fr 320px;
        gap: 0;
        margin: 22px 64px 28px;
        border: 1px solid var(--line);
        background: linear-gradient(180deg, rgba(14,8,22,0.92), rgba(8,4,14,0.95));
        box-shadow: var(--shadow-sharp);
        max-height: 270px;
      }
      .logpanel::before {
        content: "";
        position: absolute; top: -1px; left: 0; right: 0;
        height: 2px;
        background: linear-gradient(90deg, transparent, var(--red-bright) 18%, var(--gold) 50%, var(--blue-bright) 82%, transparent);
        opacity: 0.75;
      }

      .log-head {
        grid-column: 1 / -1;
        display: flex; justify-content: space-between; align-items: center;
        padding: 12px 20px;
        border-bottom: 1px solid var(--line-soft);
        background: rgba(255,255,255,0.02);
      }
      .log-title { display: flex; align-items: center; gap: 12px; }
      .log-dot {
        width: 8px; height: 8px; border-radius: 50%;
        background: var(--red-bright);
        box-shadow: 0 0 10px var(--red-bright);
      }
      .log-zh {
        font-family: "Cinzel", "Noto Serif SC", serif;
        font-size: 15px; font-weight: 700; color: var(--ink-0);
        letter-spacing: 0.34em;
      }
      .log-en {
        font-family: "Oxanium", sans-serif;
        font-size: 11px; color: var(--ink-2); letter-spacing: 0.34em;
      }
      .log-tabs { display: flex; gap: 4px; }
      .tab {
        background: transparent; border: 1px solid transparent;
        color: var(--ink-2);
        padding: 5px 14px;
        font-size: 12px; letter-spacing: 0.22em; cursor: pointer;
        clip-path: polygon(7px 0, 100% 0, calc(100% - 7px) 100%, 0 100%);
        transition: color 150ms ease, background 150ms ease;
      }
      .tab:hover { color: var(--ink-0); background: rgba(255,255,255,0.04); }
      .tab.active {
        color: var(--gold);
        background: rgba(255,200,80,0.08);
        border-color: var(--gold-dim);
      }

      .log-list {
        list-style: none; margin: 0; padding: 8px 8px 8px 14px;
        overflow-y: auto;
        max-height: 218px;
        font-family: "Oxanium", "Noto Sans SC", monospace;
        scrollbar-color: var(--line) transparent;
        scrollbar-width: thin;
      }
      .log-list::-webkit-scrollbar { width: 7px; }
      .log-list::-webkit-scrollbar-thumb { background: var(--line); }

      .log-row {
        display: grid;
        grid-template-columns: 64px 42px 1fr auto;
        gap: 14px;
        align-items: center;
        padding: 6px 10px;
        font-size: 14px;
        color: var(--ink-1);
        border-bottom: 1px dashed rgba(255,255,255,0.05);
        line-height: 1.5;
      }
      .log-row:last-child { border-bottom: 0; }
      .log-row.crit { background: linear-gradient(90deg, rgba(255,180,60,0.09), transparent 70%); }
      .log-row.sys { color: var(--ink-2); font-style: italic; }
      .log-t { font-size: 12px; color: var(--ink-2); letter-spacing: 0.14em; }
      .log-side {
        font-size: 10px; font-weight: 800; letter-spacing: 0.22em;
        padding: 3px 0; text-align: center;
        border: 1px solid var(--line);
      }
      .log-side.red { color: var(--red-bright); border-color: rgba(255,80,80,0.4); background: rgba(255,40,60,0.08); }
      .log-side.blue { color: var(--blue-bright); border-color: rgba(80,180,255,0.4); background: rgba(40,140,255,0.08); }
      .log-side.sys { color: var(--ink-2); }
      .log-text { color: var(--ink-0); }
      .log-row.sys .log-text { color: var(--ink-2); }
      .log-dmg {
        font-family: "Oxanium", monospace;
        font-weight: 800; font-size: 15px;
        padding: 0 8px;
      }
      .log-dmg.crit { color: var(--crit); text-shadow: 0 0 8px rgba(255,200,80,0.55); }
      .log-dmg.hit { color: var(--red-bright); }
      .log-dmg.block { color: var(--ink-1); }
      .log-dmg.buff { color: var(--blue-bright); }
      .log-dmg.sys { color: var(--ink-2); }

      .log-actions {
        display: flex; flex-direction: column;
        gap: 8px;
        padding: 12px;
        border-left: 1px solid var(--line-soft);
        background: rgba(255,255,255,0.015);
      }
      .act {
        position: relative;
        display: grid;
        grid-template-columns: 32px 1fr auto;
        align-items: center;
        gap: 12px;
        padding: 10px 12px;
        background: linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.01));
        border: 1px solid var(--line);
        color: var(--ink-0);
        cursor: pointer;
        text-align: left;
        transition: transform 120ms ease, border-color 200ms ease, box-shadow 200ms ease;
        clip-path: polygon(10px 0, 100% 0, calc(100% - 10px) 100%, 0 100%);
      }
      .act::after {
        content: "►";
        font-size: 10px;
        color: var(--ink-2);
        letter-spacing: 0.1em;
      }
      .act:hover { transform: translateY(-1px); border-color: var(--gold-dim); box-shadow: 0 0 18px rgba(255,200,80,0.15); }
      .act-key {
        font-family: "Oxanium", monospace;
        font-size: 12px; font-weight: 800; letter-spacing: 0.05em;
        color: var(--ink-2);
        padding: 3px 0;
        text-align: center;
        border: 1px solid var(--line-soft);
        background: rgba(0,0,0,0.4);
      }
      .act-label {
        font-family: "Cinzel", "Noto Sans SC", serif;
        font-size: 14px; font-weight: 700; letter-spacing: 0.24em;
      }
      .act.primary {
        background: linear-gradient(180deg, rgba(255,60,90,0.35), rgba(120,10,30,0.5));
        border-color: rgba(255,80,110,0.5);
        box-shadow: 0 0 24px rgba(255,40,80,0.25), inset 0 1px 0 rgba(255,255,255,0.18);
      }
      .act.primary .act-key { color: #ffd5d5; border-color: rgba(255,200,200,0.4); background: rgba(120,10,30,0.5); }
      .act.primary::after { color: #ffd5d5; }
      .act.warn {
        background: linear-gradient(180deg, rgba(255,200,80,0.08), rgba(80,40,8,0.4));
        border-color: var(--gold-dim);
        color: var(--gold);
      }
      .act.warn .act-key { color: var(--gold); border-color: var(--gold-dim); }
      .act.warn::after { color: var(--gold); }

      @media (prefers-reduced-motion: reduce) {
        .round-ring, .hpfill.low, .time-dot, .portrait-pulse, .vs-glow, .impact-num { animation: none; }
      }
    `}</style>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
