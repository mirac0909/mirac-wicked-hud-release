const app = document.getElementById('app');
const vehiclePanel = document.getElementById('vehicle-panel');
const vehicleDetailPanel = document.getElementById('vehicle-detail-panel');
const hudNotifications = document.getElementById('hud-notifications');
const hudTextUi = document.getElementById('hud-textui');
const hudTextUiIcon = document.getElementById('hud-textui-icon');
const hudTextUiText = document.getElementById('hud-textui-text');
const identityPanel = document.getElementById('identity-panel');
const locationPanel = document.getElementById('location-panel');
const statusDock = document.getElementById('status-dock');
const identitySummary = document.querySelector('.identity-summary');
const minimapFrame = document.getElementById('minimap-frame');
const voiceIndicator = document.getElementById('voice');
const speedUnitLabel = document.getElementById('speed-unit');
const settingsPanel = document.getElementById('hud-settings');
const settingsVisibility = document.getElementById('settings-visibility');
const settingsVisibilityLabel = document.getElementById('settings-visibility-label');
const settingsLocation = document.getElementById('settings-location');
const settingsPreview = document.getElementById('settings-preview');
const settingsModeButtons = [...document.querySelectorAll('[data-settings-mode]')];
const settingsVehicleModeButtons = [...document.querySelectorAll('[data-settings-vehicle-mode]')];
const settingsPositionButtons = [...document.querySelectorAll('[data-settings-position]')];
const settingsPaletteButtons = [...document.querySelectorAll('[data-settings-palette]')];
const settingsOpacity = document.getElementById('settings-opacity');
const settingsOpacityValue = document.getElementById('settings-opacity-value');
const settingsCloseButtons = [...document.querySelectorAll('[data-settings-close]')];
// Keep a changing status mounted until its value has genuinely settled.
// This prevents repeated close/reopen motion around zero and during recovery.
const STATUS_CHANGE_HOLD_MS = 2800;
const STATUS_FILL_HOLD_MS = 5000;
const STATUS_EXIT_MS = 320;
const STATUS_EXIT_STAGGER_MS = 225;
const MODE_SWITCH_MS = 220;
const RACE_MODE_SWITCH_OUT_MS = 150;
const RACE_MODE_SWITCH_IN_MS = 260;
const VEHICLE_CRASH_EFFECT_MS = 820;
const SETTINGS_REQUEST_TIMEOUT_MS = 5000;
const HUD_POSITION_CLASSES = ['hud-position-top-right', 'hud-position-top-left', 'hud-position-bottom-right'];
const HUD_PALETTES = ['ocean', 'emerald', 'amethyst', 'amber', 'graphite', 'ruby', 'sakura', 'frost', 'royal', 'lime', 'copper', 'coral', 'petrol', 'orchid', 'sage'];
let vehicleMode = false;
let vehicleRevealReady = false;
let vehicleRevealDelayTimer = null;
let vehicleExitTimer = null;
let vehicleExiting = false;
let showAllStatuses = false;
let showAllExitTimer = null;
let modeSwitching = false;
let modeSwitchTimer = null;
let vehicleEntryTimer = null;
let identityHandoffTimer = null;
let summaryHandoffTimer = null;
let summaryLayoutTransition = null;
let voiceLayoutTransition = null;
let activeHudPosition = '';
let activeHudPalette = '';
let activeRaceMode = null;
let raceModeSwitchTimer = null;
let vehicleCrashEffectTimer = null;
let settingsRequestPending = false;
let settingsRequestController = null;
let settingsQueueGeneration = 0;
const settingsActionQueue = [];
const rootStyleCache = new Map();
const appStyleCache = new Map();
const hudNotificationRecords = new Map();
let hudSettingsState = {
  enabled: true,
  location: true,
  minimal: false,
  ultraMinimal: false,
  raceMode: false,
  position: 'top-right',
  palette: 'ocean',
  opacity: 100,
  notificationSafetyLimit: 100
};

const DEFAULT_HUD_STATE = {
  health: 100,
  armour: 0,
  stamina: 100,
  oxygen: false,
  hunger: false,
  thirst: false,
  talking: false,
  voiceMode: 2,
  temporaryId: 0,
  permanentId: '0',
  time: '00:00',
  compass: 'K',
  street: '',
  area: '',
  showAllStatuses: false,
  vehicle: false
};

let hudState = { ...DEFAULT_HUD_STATE };
let hudConfig = {
  minimalMode: false,
  ultraMinimalMode: false,
  raceMode: false,
  locationVisible: true,
  hudPosition: 'top-right',
  speedUnit: 'kmh',
  components: {},
  vehicleWarnings: { warningThreshold: 60, dangerThreshold: 35 },
  vehicleDetails: { enabled: true },
  identity: { serverLabel: 'OX', permanentIdMaxLength: 12 },
  palette: 'ocean',
  opacity: 100
};
let uiLocale = {
  enabled: 'Enabled',
  disabled: 'Disabled',
  locating: 'Locating',
  notification: 'Notification',
  voice_mode_status: 'Voice mode: %s',
  voice_mode_whisper: 'Whisper',
  voice_mode_normal: 'Normal',
  voice_mode_shout: 'Shout',
  nitro_percent: 'Nitro: %s%'
};

function translate(key, value) {
  const template = String(uiLocale[key] ?? key);
  return value === undefined ? template : template.replace('%s', String(value));
}

const VOICE_MODE_KEYS = {
  1: 'voice_mode_whisper',
  2: 'voice_mode_normal',
  3: 'voice_mode_shout'
};

function normalizeVoiceMode(value) {
  const mode = Math.floor(Number(value));
  return mode >= 1 && mode <= 3 ? mode : 2;
}

function setVoiceMode(value) {
  const mode = normalizeVoiceMode(value);
  const label = translate(VOICE_MODE_KEYS[mode]);
  const description = translate('voice_mode_status', label);

  fields.voice.dataset.voiceMode = String(mode);
  fields.voice.setAttribute('title', description);
  fields.voice.setAttribute('aria-label', description);
  return mode;
}

function applyLocale(strings = {}, language) {
  if (!strings || typeof strings !== 'object') return;
  uiLocale = { ...uiLocale, ...strings };
  if (typeof language === 'string' && language) document.documentElement.lang = language;

  document.querySelectorAll('[data-i18n]').forEach((element) => {
    const key = element.dataset.i18n;
    if (uiLocale[key] !== undefined) element.textContent = translate(key);
  });
  document.querySelectorAll('[data-i18n-aria]').forEach((element) => {
    const key = element.dataset.i18nAria;
    if (uiLocale[key] !== undefined) element.setAttribute('aria-label', translate(key));
  });
  document.querySelectorAll('[data-i18n-title]').forEach((element) => {
    const key = element.dataset.i18nTitle;
    if (uiLocale[key] !== undefined) element.setAttribute('title', translate(key));
  });

  const closeHint = document.querySelector('[data-i18n-html="close_hint"]');
  if (closeHint && uiLocale.close_hint !== undefined) {
    const hint = translate('close_hint').replace(/^ESC\s*/i, '');
    closeHint.innerHTML = `<span>ESC</span> ${hint}`;
  }

  settingsVisibilityLabel.textContent = translate(hudSettingsState.enabled ? 'enabled' : 'disabled');
  if (!hudState.street) fields.street.textContent = translate('locating');
  setVoiceMode(hudState.voiceMode);
  if (vehicleUi.nitroGauge.classList.contains('is-seatbelt')) {
    vehicleUi.nitroGauge.setAttribute(
      'aria-label',
      translate(vehicleUi.nitroGauge.classList.contains('is-unbuckled') ? 'seatbelt_off' : 'seatbelt_on')
    );
  } else {
    vehicleUi.nitroGauge.setAttribute('aria-label', translate('nitro_percent', lastNitroValue ?? 0));
  }
  renderRaceSeatbelt();
}

function setComponentVisible(element, visible) {
  if (!element) return;
  element.classList.toggle('is-component-disabled', visible === false);
}

function setCachedStyle(element, cache, property, value) {
  if (!element || cache.get(property) === value) return;
  cache.set(property, value);
  element.style.setProperty(property, value);
}

function applyConfig(config = {}) {
  if (!config || typeof config !== 'object') return;
  hudConfig = {
    ...hudConfig,
    ...config,
    components: { ...hudConfig.components, ...(config.components || {}) }
  };

  if (Object.hasOwn(config, 'minimalMode') || Object.hasOwn(config, 'ultraMinimalMode')) applyFootDisplayMode();
  if (Object.hasOwn(config, 'raceMode')) setVehicleRaceMode(Boolean(config.raceMode));
  if (Object.hasOwn(config, 'hudPosition')) setHudPosition(config.hudPosition);
  if (Object.hasOwn(config, 'palette')) setHudPalette(config.palette);
  if (Object.hasOwn(config, 'opacity')) setHudOpacity(config.opacity);
  if (config.identity && Object.hasOwn(config.identity, 'serverLabel')) {
    fields.serverLabel.textContent = String(config.identity.serverLabel || 'OX').slice(0, 12);
  }

  const unit = hudConfig.speedUnit === 'mph' ? 'MPH' : 'KM/H';
  if (speedUnitLabel) speedUnitLabel.textContent = unit;

  const safeZone = hudConfig.safeZone && typeof hudConfig.safeZone === 'object' ? hudConfig.safeZone : {};
  const safeX = Math.min(10, Math.max(0, Number(safeZone.x) || 0));
  const safeY = Math.min(10, Math.max(0, Number(safeZone.y) || 0));
  setCachedStyle(document.documentElement, rootStyleCache, '--safe-zone-x', `${safeX}vw`);
  setCachedStyle(document.documentElement, rootStyleCache, '--safe-zone-y', `${safeY}vh`);

  const components = hudConfig.components;
  setComponentVisible(identityPanel, components.identity);
  setComponentVisible(
    locationPanel,
    components.location !== false && hudConfig.locationVisible !== false
  );
  setComponentVisible(statusDock, components.statuses);
  setComponentVisible(identitySummary, components.statuses);
  setComponentVisible(vehiclePanel, components.vehicle);
  setComponentVisible(vehicleDetailPanel, components.vehicle && hudConfig.vehicleDetails?.enabled !== false);
  setComponentVisible(voiceIndicator, components.voice);
  setComponentVisible(minimapFrame, components.minimap);
}

const fields = {
  serverLabel: document.getElementById('server-label'),
  serverId: document.getElementById('server-id'),
  temporaryId: document.getElementById('temporary-id'),
  permanentId: document.getElementById('permanent-id'),
  time: document.getElementById('game-time'),
  voice: voiceIndicator,
  compass: document.getElementById('compass'),
  street: document.getElementById('street'),
  area: document.getElementById('area'),
  speed: document.getElementById('speed-value'),
  gear: document.getElementById('gear-value'),
  fuel: document.getElementById('fuel-value'),
  engine: document.getElementById('engine-value')
};

const vehicleUi = {
  gearPrevious: document.getElementById('gear-previous'),
  gearRpmRing: document.getElementById('gear-rpm-value'),
  raceRpmBar: document.getElementById('race-rpm-bar'),
  gearShell: document.querySelector('.gear-shell'),
  fuelBar: document.getElementById('fuel-bar'),
  engineBar: document.getElementById('engine-bar'),
  fuelArc: document.getElementById('fuel-arc-value'),
  engineArc: document.getElementById('engine-arc-value'),
  nitroGauge: document.getElementById('nitro-gauge'),
  nitroRing: document.getElementById('nitro-ring-value'),
  raceNitroValue: document.getElementById('race-nitro-value'),
  raceSeatbelt: document.getElementById('race-seatbelt-light'),
  detailNitro: document.getElementById('vehicle-detail-nitro'),
  detailNitroValue: document.getElementById('vehicle-detail-nitro-value')
};

const RACE_METER_SEGMENT_COUNT = 10;
const RACE_METER_START_ANGLE = 125;
const RACE_METER_ANGLE_STEP = 29;
const RACE_METER_SEGMENT_GAP = 2;
const RACE_METER_CENTER_X = 50;
const RACE_METER_CENTER_Y = 50.7;
const RACE_METER_RADIUS_X = 43.1;
const RACE_METER_RADIUS_Y = 39.2;

function raceMeterPoint(angle) {
  const radians = angle * Math.PI / 180;
  return {
    x: RACE_METER_CENTER_X + (RACE_METER_RADIUS_X * Math.cos(radians)),
    y: RACE_METER_CENTER_Y + (RACE_METER_RADIUS_Y * Math.sin(radians))
  };
}

function buildRaceMeterSegments(name) {
  const group = document.querySelector(`[data-race-meter="${name}"]`);
  if (!group) return [];

  const fragment = document.createDocumentFragment();
  const segments = [];
  for (let index = 0; index < RACE_METER_SEGMENT_COUNT; index += 1) {
    const track = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    const segment = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    const zoneClass = index < 3 ? ' is-low-zone' : (index >= 6 ? ' is-high-zone' : '');
    track.setAttribute('class', 'race-meter-segment-track');
    segment.setAttribute('class', `race-meter-segment${zoneClass}`);
    track.setAttribute('pathLength', '100');
    segment.setAttribute('pathLength', '100');
    const startAngle = RACE_METER_START_ANGLE + (index * RACE_METER_ANGLE_STEP) + RACE_METER_SEGMENT_GAP;
    const isLastSegment = index === RACE_METER_SEGMENT_COUNT - 1;
    const endAngle = RACE_METER_START_ANGLE
      + ((index + 1) * RACE_METER_ANGLE_STEP)
      - (isLastSegment ? 0 : RACE_METER_SEGMENT_GAP);
    const start = raceMeterPoint(startAngle);
    const end = raceMeterPoint(endAngle);
    const pathData = `M${start.x.toFixed(2)} ${start.y.toFixed(2)}A${RACE_METER_RADIUS_X} ${RACE_METER_RADIUS_Y} 0 0 1 ${end.x.toFixed(2)} ${end.y.toFixed(2)}`;
    track.setAttribute('d', pathData);
    segment.setAttribute('d', pathData);
    fragment.appendChild(track);
    fragment.appendChild(segment);
    segments.push(segment);
  }
  group.appendChild(fragment);
  return segments;
}

vehicleUi.fuelSegments = buildRaceMeterSegments('fuel');
vehicleUi.engineSegments = buildRaceMeterSegments('engine');

let lastNitroValue = null;
let nitroChangeTimer = null;
let nitroEmptyAttemptAnimation = null;
let nitroEmptyAttemptTimer = null;
let safetySlotTimer = null;
let safetySlotTransitionTimer = null;
let safetySlotOwner = null;
let lastSeatbeltState = null;
let lastNitroActive = false;
let lastHadNitro = false;
let vehicleSafetyState = {
  hasNitro: false,
  nitro: 0,
  seatbelt: false,
  seatbeltAvailable: false
};

const NITRO_SLOT_HOLD_MS = 1600;
const BUCKLED_SLOT_HOLD_MS = 1100;
const EMPTY_NITRO_SLOT_HOLD_MS = 950;
const SAFETY_SLOT_SWITCH_MS = 330;

const statuses = {
  health: {
    value: document.getElementById('health-value'),
    bar: document.getElementById('health-bar'),
    summary: document.getElementById('summary-health'),
    card: document.querySelector('[data-status="health"]')
  },
  armour: {
    value: document.getElementById('armour-value'),
    bar: document.getElementById('armour-bar'),
    summary: document.getElementById('summary-armour'),
    card: document.querySelector('[data-status="armour"]')
  },
  stamina: {
    value: document.getElementById('stamina-value'),
    bar: document.getElementById('stamina-bar'),
    summary: document.getElementById('summary-stamina'),
    card: document.querySelector('[data-status="stamina"]')
  },
  oxygen: {
    value: document.getElementById('oxygen-value'),
    bar: document.getElementById('oxygen-bar'),
    summary: document.getElementById('summary-oxygen'),
    card: document.getElementById('oxygen-card'),
    optional: true
  },
  hunger: {
    value: document.getElementById('hunger-value'),
    bar: document.getElementById('hunger-bar'),
    summary: document.getElementById('summary-hunger'),
    card: document.getElementById('hunger-card'),
    optional: true
  },
  thirst: {
    value: document.getElementById('thirst-value'),
    bar: document.getElementById('thirst-bar'),
    summary: document.getElementById('summary-thirst'),
    card: document.getElementById('thirst-card'),
    optional: true
  }
};

const STATUS_ORDER = ['health', 'armour', 'stamina', 'oxygen', 'hunger', 'thirst'];
const identityStatusCard = document.querySelector('.status-identity-ids');
const CRITICAL_INDICATOR_PULSE_MS = 1450;
let statusAnchorFrame = null;

function primeCriticalIndicatorPhase(card) {
  if (!card) return;
  const phase = performance.now() % CRITICAL_INDICATOR_PULSE_MS;
  card.style.setProperty('--critical-pulse-delay', `${-phase}ms`);
}

function syncCriticalStatusState() {
  const hasCriticalStatus = STATUS_ORDER.some((name) => {
    const card = statuses[name]?.card;
    return card
      && !card.classList.contains('is-hidden')
      && card.classList.contains('is-critical');
  });

  app.classList.toggle('has-critical-status', hasCriticalStatus);
}

function getOpenStatusCards() {
  const isMinimalCollapsed = app.classList.contains('is-minimal')
    && !showAllStatuses
    && !app.classList.contains('is-status-exiting');

  if (isMinimalCollapsed && !app.classList.contains('has-critical-status')) return [];

  const revealAll = showAllStatuses || app.classList.contains('is-status-exiting');

  const cards = STATUS_ORDER
    .map((name) => statuses[name].card)
    .filter((card) => !card.classList.contains('is-hidden'))
    .filter((card) => revealAll
      || card.classList.contains('is-critical')
      || card.classList.contains('is-changing')
      || card.classList.contains('is-leaving'));

  if (revealAll && identityStatusCard) cards.push(identityStatusCard);
  return cards;
}

function assignStatusAnimationDelays() {
  const cards = getOpenStatusCards();
  const lastIndex = cards.length - 1;
  const step = lastIndex > 0 ? STATUS_EXIT_STAGGER_MS / lastIndex : 0;

  cards.forEach((card, index) => {
    card.style.setProperty('--deploy-delay', `${Math.round(index * step)}ms`);
    card.style.setProperty('--exit-delay', `${Math.round((lastIndex - index) * step)}ms`);
  });
}

function syncTopStatusAnchor() {
  statusAnchorFrame = null;
  syncTransientAnchors();

  const topStatusName = STATUS_ORDER.find((name) => {
    const card = statuses[name].card;
    const style = window.getComputedStyle(card);
    return !card.classList.contains('is-hidden') && style.display !== 'none' && style.visibility !== 'hidden';
  });

  STATUS_ORDER.forEach((name) => {
    statuses[name].card.classList.toggle('is-top-status', name === topStatusName);
  });

  if (!topStatusName) return;

  const status = statuses[topStatusName];
  const segment = status.summary?.parentElement;
  if (!segment) return;

  const cardRect = status.card.getBoundingClientRect();
  const segmentRect = segment.getBoundingClientRect();
  if (!cardRect.width || !segmentRect.width) return;

  const scaledOffset = segmentRect.left + (segmentRect.width / 2) - cardRect.left;
  const anchor = (scaledOffset / cardRect.width) * status.card.offsetWidth;
  const safeAnchor = Math.min(status.card.offsetWidth - 12, Math.max(12, anchor));
  status.card.style.setProperty('--status-anchor-x', `${safeAnchor.toFixed(2)}px`);
}

function syncTransientAnchors() {
  const gap = 7;

  if (app.classList.contains('is-vehicle')) {
    const mapRect = minimapFrame?.getBoundingClientRect();
    const vehicleRect = vehiclePanel?.getBoundingClientRect();
    const detailIsVisible = app.classList.contains('is-peeking')
      && !app.classList.contains('is-panels-hidden')
      && vehicleDetailPanel?.classList.contains('has-nitro')
      && !vehicleDetailPanel.classList.contains('is-hidden')
      && !vehicleDetailPanel.classList.contains('is-component-disabled');
    const detailRect = detailIsVisible
      ? vehicleDetailPanel.getBoundingClientRect()
      : null;

    if (mapRect?.width) {
      setCachedStyle(app, appStyleCache, '--vehicle-notification-left', `${mapRect.left.toFixed(2)}px`);
      setCachedStyle(app, appStyleCache, '--vehicle-notification-bottom', `${(window.innerHeight - mapRect.top + gap).toFixed(2)}px`);
      setCachedStyle(app, appStyleCache, '--vehicle-notification-width', `${mapRect.width.toFixed(2)}px`);
    }

    if (vehicleRect?.width) {
      setCachedStyle(app, appStyleCache, '--vehicle-textui-left', `${vehicleRect.left.toFixed(2)}px`);
      const textUiAnchorTop = detailRect?.height > 0 ? detailRect.top : vehicleRect.top;
      setCachedStyle(app, appStyleCache, '--vehicle-textui-bottom', `${(window.innerHeight - textUiAnchorTop + gap).toFixed(2)}px`);
      setCachedStyle(app, appStyleCache, '--vehicle-textui-width', `${vehicleRect.width.toFixed(2)}px`);
    }
    return;
  }

  const identityRect = identityPanel?.getBoundingClientRect();
  if (!identityRect?.width) return;
  const statusRects = getOpenStatusCards()
    .map((card) => card.getBoundingClientRect())
    .filter((rect) => rect.width > 0 && rect.height > 0);
  const groupRects = [identityRect, ...statusRects];
  const referenceRect = statusRects[0] || identityRect;

  setCachedStyle(app, appStyleCache, '--ped-textui-left', `${referenceRect.left.toFixed(2)}px`);
  setCachedStyle(app, appStyleCache, '--ped-textui-width', `${referenceRect.width.toFixed(2)}px`);
  if (app.classList.contains('hud-position-bottom-right')) {
    setCachedStyle(app, appStyleCache, '--ped-textui-top', 'auto');
    const groupTop = Math.min(...groupRects.map((rect) => rect.top));
    const textUiBottom = window.innerHeight - groupTop + gap;
    setCachedStyle(app, appStyleCache, '--ped-textui-bottom', `${textUiBottom.toFixed(2)}px`);
    const notificationBottom = hudTextUi?.classList.contains('is-visible')
      ? textUiBottom + hudTextUi.getBoundingClientRect().height + gap
      : textUiBottom;
    setCachedStyle(app, appStyleCache, '--ped-notification-top', 'auto');
    setCachedStyle(app, appStyleCache, '--ped-notification-bottom', `${notificationBottom.toFixed(2)}px`);
  } else {
    const groupBottom = Math.max(...groupRects.map((rect) => rect.bottom));
    const textUiTop = groupBottom + gap;
    setCachedStyle(app, appStyleCache, '--ped-textui-top', `${textUiTop.toFixed(2)}px`);
    setCachedStyle(app, appStyleCache, '--ped-textui-bottom', 'auto');
    const notificationTop = hudTextUi?.classList.contains('is-visible')
      ? textUiTop + hudTextUi.getBoundingClientRect().height + gap
      : textUiTop;
    setCachedStyle(app, appStyleCache, '--ped-notification-top', `${notificationTop.toFixed(2)}px`);
    setCachedStyle(app, appStyleCache, '--ped-notification-bottom', 'auto');
  }
  setCachedStyle(app, appStyleCache, '--ped-notification-left', `${referenceRect.left.toFixed(2)}px`);
  setCachedStyle(app, appStyleCache, '--ped-notification-width', `${referenceRect.width.toFixed(2)}px`);
}

function scheduleTopStatusAnchor() {
  if (statusAnchorFrame !== null) return;
  statusAnchorFrame = window.requestAnimationFrame(syncTopStatusAnchor);
}

const statusAnchorObserver = new MutationObserver(scheduleTopStatusAnchor);
statusAnchorObserver.observe(app, {
  subtree: true,
  attributes: true,
  attributeFilter: ['class']
});
window.addEventListener('resize', () => {
  scheduleTopStatusAnchor();
  refreshMarquees();
});
const transientAnchorObserver = new ResizeObserver(scheduleTopStatusAnchor);
[identityPanel, minimapFrame, vehiclePanel, vehicleDetailPanel, hudTextUi].forEach((element) => {
  if (element) transientAnchorObserver.observe(element);
});

function clamp(value) {
  return Math.min(100, Math.max(0, Number(value) || 0));
}

function numericId(value, maximumLength) {
  const digits = String(value ?? '').replace(/\D/g, '');
  return digits.slice(0, Math.max(1, Number(maximumLength) || 12)) || '0';
}

function mergeState(target, patch) {
  if (!patch || typeof patch !== 'object' || Array.isArray(patch)) return patch;
  const base = target && typeof target === 'object' && !Array.isArray(target) ? target : {};
  const result = { ...base };

  Object.entries(patch).forEach(([key, value]) => {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      result[key] = mergeState(base[key], value);
    } else {
      result[key] = value;
    }
  });

  return result;
}

function setVisible(state) {
  const visibility = typeof state === 'object'
    ? state
    : { panelsVisible: Boolean(state), notificationsVisible: Boolean(state), textUiVisible: Boolean(state) };
  const panelsVisible = Boolean(visibility.panelsVisible ?? visibility.visible);
  const notificationsVisible = Boolean(visibility.notificationsVisible ?? panelsVisible);
  const textUiVisible = Boolean(visibility.textUiVisible ?? panelsVisible);
  app.classList.toggle('is-panels-hidden', !panelsVisible);
  app.classList.toggle('are-notifications-hidden', !notificationsVisible);
  app.classList.toggle('is-textui-hidden', !textUiVisible);
  app.classList.toggle('is-transient-hidden', !notificationsVisible && !textUiVisible);
  app.setAttribute('aria-hidden', panelsVisible || notificationsVisible || textUiVisible ? 'false' : 'true');
}

function renderHudSettings(state = {}) {
  hudSettingsState = {
    enabled: state.enabled !== false,
    location: state.location !== false,
    minimal: Boolean(state.minimal),
    ultraMinimal: Boolean(state.ultraMinimal),
    raceMode: Boolean(state.raceMode),
    position: ['top-left', 'bottom-right'].includes(state.position) ? state.position : 'top-right',
    palette: HUD_PALETTES.includes(state.palette) ? state.palette : 'ocean',
    opacity: normalizeHudOpacity(state.opacity)
  };

  settingsVisibility.classList.toggle('is-active', hudSettingsState.enabled);
  settingsVisibility.setAttribute('aria-pressed', hudSettingsState.enabled ? 'true' : 'false');
  settingsVisibilityLabel.textContent = translate(hudSettingsState.enabled ? 'enabled' : 'disabled');

  settingsLocation.classList.toggle('is-active', hudSettingsState.location);
  settingsLocation.setAttribute('aria-pressed', hudSettingsState.location ? 'true' : 'false');

  const activeMode = hudSettingsState.ultraMinimal ? 'ultra' : (hudSettingsState.minimal ? 'minimal' : 'normal');
  settingsModeButtons.forEach((button) => {
    const active = button.dataset.settingsMode === activeMode;
    button.classList.toggle('is-active', active);
    button.setAttribute('aria-pressed', active ? 'true' : 'false');
  });

  const activeVehicleMode = hudSettingsState.raceMode ? 'race' : 'normal';
  settingsVehicleModeButtons.forEach((button) => {
    const active = button.dataset.settingsVehicleMode === activeVehicleMode;
    button.classList.toggle('is-active', active);
    button.setAttribute('aria-pressed', active ? 'true' : 'false');
  });

  settingsPositionButtons.forEach((button) => {
    const active = button.dataset.settingsPosition === hudSettingsState.position;
    button.classList.toggle('is-active', active);
    button.setAttribute('aria-pressed', active ? 'true' : 'false');
  });

  settingsPaletteButtons.forEach((button) => {
    const active = button.dataset.settingsPalette === hudSettingsState.palette;
    button.classList.toggle('is-active', active);
    button.setAttribute('aria-pressed', active ? 'true' : 'false');
  });

  if (settingsOpacity) settingsOpacity.value = String(hudSettingsState.opacity);
  if (settingsOpacityValue) settingsOpacityValue.textContent = `${hudSettingsState.opacity}%`;

  setHudPalette(hudSettingsState.palette);
  setHudOpacity(hudSettingsState.opacity);
  setVehicleRaceMode(hudSettingsState.raceMode);
}

function setSettingsVisible(open, state) {
  if (state) renderHudSettings(state);
  settingsPanel.classList.toggle('is-hidden', !open);
  settingsPanel.setAttribute('aria-hidden', open ? 'false' : 'true');
}

function setSettingsBusy(busy) {
  settingsPanel.classList.toggle('is-busy', busy);
  settingsPanel.setAttribute('aria-busy', busy ? 'true' : 'false');
}

function clearSettingsActionQueue() {
  settingsQueueGeneration += 1;
  settingsActionQueue.length = 0;
  settingsRequestController?.abort();
  settingsRequestController = null;
  settingsRequestPending = false;
  setSettingsBusy(false);
}

async function processSettingsActions() {
  if (settingsRequestPending || !settingsActionQueue.length) return;
  const generation = settingsQueueGeneration;
  settingsRequestPending = true;
  setSettingsBusy(true);

  while (settingsActionQueue.length && generation === settingsQueueGeneration) {
    const request = settingsActionQueue.shift();
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), SETTINGS_REQUEST_TIMEOUT_MS);
    settingsRequestController = controller;

    try {
      const response = await fetch(`https://${GetParentResourceName()}/hudSettingsAction`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(request),
        signal: controller.signal
      });
      const result = await response.json();
      if (result?.state) renderHudSettings(result.state);
    } catch (error) {
      if (error?.name !== 'AbortError') console.warn('HUD settings action failed', error);
      else console.warn('HUD settings action timed out');
    } finally {
      window.clearTimeout(timeout);
      if (settingsRequestController === controller) settingsRequestController = null;
    }
  }

  if (generation === settingsQueueGeneration) {
    settingsRequestPending = false;
    setSettingsBusy(false);
  }
}

function sendSettingsAction(action, value) {
  const coalescedActions = new Set(['setMode', 'setVehicleMode', 'setPosition', 'setPalette', 'setOpacity']);
  if (coalescedActions.has(action)) {
    for (let index = settingsActionQueue.length - 1; index >= 0; index -= 1) {
      if (settingsActionQueue[index].action === action) settingsActionQueue.splice(index, 1);
    }
  }

  settingsActionQueue.push({ action, value });
  void processSettingsActions();
}

function applyFootDisplayMode() {
  const ultraMinimal = Boolean(hudConfig.ultraMinimalMode);
  const minimal = Boolean(hudConfig.minimalMode) && !ultraMinimal;
  app.classList.toggle('is-minimal', minimal || ultraMinimal);
  app.classList.toggle('is-ultra-minimal', ultraMinimal);
  STATUS_ORDER.forEach((name) => {
    const value = statuses[name]?.lastValue;
    if (Number.isFinite(value)) updateStatus(name, value, false);
  });
  syncCriticalStatusState();
  setShowAllStatuses(!minimal && !ultraMinimal);
  scheduleTopStatusAnchor();
}

function setVehicleRaceMode(enabled) {
  const nextRaceMode = Boolean(enabled);
  if (activeRaceMode === nextRaceMode) return;

  const firstApply = activeRaceMode === null;
  activeRaceMode = nextRaceMode;
  window.clearTimeout(raceModeSwitchTimer);
  raceModeSwitchTimer = null;
  vehiclePanel.classList.remove('is-race-switching-out', 'is-race-switching-in');

  const applyRaceMode = () => {
    app.classList.toggle('is-race-mode', nextRaceMode);
    renderSafetySlot();
    renderRaceSeatbelt();
    scheduleTopStatusAnchor();

    if (firstApply || !vehicleMode || vehicleExiting) return;

    void vehiclePanel.offsetWidth;
    vehiclePanel.classList.add('is-race-switching-in');
    raceModeSwitchTimer = window.setTimeout(() => {
      raceModeSwitchTimer = null;
      vehiclePanel.classList.remove('is-race-switching-in');
      scheduleTopStatusAnchor();
    }, RACE_MODE_SWITCH_IN_MS);
  };

  if (firstApply || !vehicleMode || vehicleExiting) {
    applyRaceMode();
    return;
  }

  vehiclePanel.classList.add('is-race-switching-out');
  raceModeSwitchTimer = window.setTimeout(() => {
    raceModeSwitchTimer = null;
    vehiclePanel.classList.remove('is-race-switching-out');
    applyRaceMode();
  }, RACE_MODE_SWITCH_OUT_MS);
}

function setHudPalette(palette) {
  const safePalette = HUD_PALETTES.includes(palette) ? palette : 'ocean';
  if (activeHudPalette === safePalette) return;
  document.documentElement.dataset.hudPalette = safePalette;
  activeHudPalette = safePalette;
}

function normalizeHudOpacity(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return 85;
  return Math.round(Math.min(100, Math.max(40, number)) / 5) * 5;
}

function setHudOpacity(value) {
  const opacity = normalizeHudOpacity(value);
  setCachedStyle(document.documentElement, rootStyleCache, '--hud-opacity', (opacity / 100).toFixed(2));
  return opacity;
}

function setHudPosition(position) {
  const safePosition = ['top-left', 'bottom-right'].includes(position) ? position : 'top-right';
  if (activeHudPosition === safePosition) return;
  HUD_POSITION_CLASSES.forEach((className) => app.classList.remove(className));
  app.classList.add(`hud-position-${safePosition}`);
  activeHudPosition = safePosition;
  scheduleTopStatusAnchor();
}

function syncLeavingStatusState() {
  const hasLeavingStatus = Object.values(statuses)
    .some((status) => status.card.classList.contains('is-leaving'));
  app.classList.toggle('has-status-leaving', hasLeavingStatus);
}

function syncChangingStatusState() {
  const hasChangingStatus = Object.values(statuses)
    .some((status) => status.card.classList.contains('is-changing'));
  app.classList.toggle('has-status-changing', hasChangingStatus);
}

function clearTransientStatusRows() {
  Object.values(statuses).forEach((status) => {
    window.clearTimeout(status.changeTimer);
    window.clearTimeout(status.exitTimer);
    status.changeTimer = null;
    status.exitTimer = null;
    status.card.classList.remove('is-changing', 'is-leaving', 'is-resuming');
  });
  syncLeavingStatusState();
  syncChangingStatusState();
}

function beginStatusExit(status) {
  window.clearTimeout(status.exitTimer);
  status.exitTimer = null;
  status.card.classList.remove('is-resuming');
  if (status.card.classList.contains('is-critical')) {
    status.card.classList.remove('is-leaving');
    syncLeavingStatusState();
    return;
  }
  status.card.classList.add('is-leaving');
  app.classList.add('has-status-leaving');
  status.exitTimer = window.setTimeout(() => {
    if (status.card.classList.contains('is-critical')) {
      status.card.classList.remove('is-leaving');
      status.exitTimer = null;
      syncLeavingStatusState();
      return;
    }
    status.card.classList.remove('is-leaving');
    status.exitTimer = null;
    syncLeavingStatusState();
  }, STATUS_EXIT_MS);
}

function setShowAllStatuses(visible) {
  if (visible) {
    window.clearTimeout(showAllExitTimer);
    showAllExitTimer = null;
    app.classList.remove('is-status-exiting');
    app.classList.add('show-status-values');
    showAllStatuses = true;
    assignStatusAnimationDelays();
    return;
  }

  if (!showAllStatuses) return;

  app.classList.remove('show-status-values');
  app.classList.add('is-status-exiting');
  showAllStatuses = false;
  assignStatusAnimationDelays();
  window.clearTimeout(showAllExitTimer);
  showAllExitTimer = window.setTimeout(() => {
    app.classList.remove('is-status-exiting');
    showAllExitTimer = null;
  }, STATUS_EXIT_MS + STATUS_EXIT_STAGGER_MS);
}

function updateStatus(name, rawValue, trackChanges = true) {
  const status = statuses[name];
  if (!status) return;

  if (status.optional && (rawValue === false || rawValue === null || rawValue === undefined)) {
    window.clearTimeout(status.changeTimer);
    window.clearTimeout(status.exitTimer);
    window.clearTimeout(status.dropTimer);
    status.changeTimer = null;
    status.exitTimer = null;
    status.dropTimer = null;
    status.card.classList.add('is-hidden');
    status.card.classList.remove('is-changing', 'is-leaving', 'is-resuming', 'is-critical');
    status.card.style.removeProperty('--critical-pulse-delay');
    status.summary?.parentElement?.classList.add('is-hidden');
    status.summary?.parentElement?.classList.remove('is-critical', 'is-dropping', 'is-empty');
    status.lastValue = undefined;
    syncLeavingStatusState();
    syncChangingStatusState();
    return;
  }

  const value = Math.round(clamp(rawValue));
  const previousValue = status.lastValue;
  const wasCritical = status.card.classList.contains('is-critical');
  const criticalThreshold = app.classList.contains('is-ultra-minimal')
    && !app.classList.contains('is-vehicle') ? 20 : 50;
  const isCritical = value <= criticalThreshold && !(name === 'armour' && value === 0);
  const ultraMinimalFoot = app.classList.contains('is-ultra-minimal')
    && !app.classList.contains('is-vehicle');
  const standardMinimalFoot = app.classList.contains('is-minimal')
    && !ultraMinimalFoot
    && !app.classList.contains('is-vehicle');
  const isRecoveringAboveThreshold = ultraMinimalFoot
    && Number.isFinite(previousValue)
    && value > previousValue
    && !isCritical;
  const shouldTrackTransientChange = trackChanges
    && app.classList.contains('is-minimal')
    && (!ultraMinimalFoot || isCritical)
    && !isRecoveringAboveThreshold;

  if (isCritical && !wasCritical) {
    primeCriticalIndicatorPhase(status.card);
  }
  if (shouldTrackTransientChange && Number.isFinite(status.lastValue) && status.lastValue !== value) {
    const wasLeaving = status.card.classList.contains('is-leaving');
    const holdDuration = standardMinimalFoot && value > previousValue
      ? STATUS_FILL_HOLD_MS
      : STATUS_CHANGE_HOLD_MS;
    window.clearTimeout(status.exitTimer);
    status.exitTimer = null;
    status.card.classList.remove('is-leaving');
    status.card.classList.add('is-changing');
    if (standardMinimalFoot && wasLeaving) status.card.classList.add('is-resuming');
    window.clearTimeout(status.changeTimer);
    status.changeTimer = window.setTimeout(() => {
      status.card.classList.remove('is-changing', 'is-resuming');
      status.changeTimer = null;
      if (!status.card.classList.contains('is-critical') && !showAllStatuses) {
        beginStatusExit(status);
      }
      syncChangingStatusState();
    }, holdDuration);
  } else if (!shouldTrackTransientChange) {
    window.clearTimeout(status.changeTimer);
    status.changeTimer = null;
    status.card.classList.remove('is-changing', 'is-resuming');
    if (!status.card.classList.contains('is-leaving')) {
      window.clearTimeout(status.exitTimer);
      status.exitTimer = null;
    }
    syncLeavingStatusState();
  }
  syncChangingStatusState();

  status.lastValue = value;
  status.card.classList.remove('is-hidden');
  status.summary?.parentElement?.classList.remove('is-hidden');
  status.card.classList.toggle('is-critical', isCritical);
  status.summary?.parentElement?.classList.toggle('is-critical', isCritical);
  status.summary?.parentElement?.classList.toggle('is-empty', value === 0);
  if (wasCritical && !isCritical && !showAllStatuses
    && !status.card.classList.contains('is-changing')) {
    beginStatusExit(status);
  }
  if (app.classList.contains('is-minimal') && Number.isFinite(previousValue) && value < previousValue && !status.dropTimer) {
    status.summary?.parentElement?.classList.add('is-dropping');
    status.dropTimer = window.setTimeout(() => {
      status.summary?.parentElement?.classList.remove('is-dropping');
      status.dropTimer = null;
    }, 360);
  }

  status.card.style.setProperty('--arc', `${Math.round(value * 2.6)}deg`);
  status.value.textContent = value;
  status.bar.style.width = `${value}%`;
  status.summary.style.setProperty('--summary-progress', (value / 100).toFixed(2));
  if (name === 'stamina') status.summary.style.width = `${value}%`;
  status.summary.style.opacity = '1';
  status.summary.parentElement?.setAttribute('aria-valuenow', String(value));
}

function setVehicleGear(nextGear) {
  const gear = String(nextGear || 'N');
  const currentGear = fields.gear.textContent || 'N';
  if (gear === currentGear) return;

  const gearRank = (value) => {
    if (value === 'R') return -1;
    if (value === 'N') return 0;
    return Number(value) || 0;
  };
  const isUpshift = gearRank(gear) > gearRank(currentGear);

  vehicleUi.gearPrevious.textContent = currentGear;
  vehicleUi.gearPrevious.classList.remove('is-leaving-left', 'is-leaving-right');
  fields.gear.classList.remove('is-entering-right', 'is-entering-left');
  void fields.gear.offsetWidth;

  fields.gear.textContent = gear;
  vehicleUi.gearPrevious.classList.add(isUpshift ? 'is-leaving-left' : 'is-leaving-right');
  fields.gear.classList.add(isUpshift ? 'is-entering-right' : 'is-entering-left');
}

function setVehicleRpm(value) {
  const rpm = Math.round(clamp(value));
  vehicleUi.gearRpmRing.style.strokeDashoffset = String(100 - rpm);
  vehicleUi.raceRpmBar.style.width = `${rpm}%`;
  vehicleUi.raceRpmBar.style.setProperty('--race-rpm-progress', (rpm / 100).toFixed(2));
  vehicleUi.raceRpmBar.classList.toggle('is-high', rpm >= 72 && rpm < 90);
  vehicleUi.raceRpmBar.classList.toggle('is-redline', rpm >= 90);
  vehicleUi.gearShell.classList.toggle('is-rpm-high', rpm >= 72 && rpm < 90);
  vehicleUi.gearShell.classList.toggle('is-rpm-redline', rpm >= 90);
}

function setVehicleMeter(bar, value) {
  const warningThreshold = Number(hudConfig.vehicleWarnings?.warningThreshold) || 60;
  const dangerThreshold = Number(hudConfig.vehicleWarnings?.dangerThreshold) || 35;
  const arc = bar === vehicleUi.fuelBar ? vehicleUi.fuelArc : vehicleUi.engineArc;
  const segments = bar === vehicleUi.fuelBar ? vehicleUi.fuelSegments : vehicleUi.engineSegments;
  const warning = value <= warningThreshold && value > dangerThreshold;
  const danger = value <= dangerThreshold;
  bar.style.width = `${value}%`;
  bar.classList.toggle('is-warning', warning);
  bar.classList.toggle('is-danger', danger);

  if (arc) {
    arc.style.strokeDashoffset = String(value - 100);
    arc.classList.toggle('is-warning', warning);
    arc.classList.toggle('is-danger', danger);
  }

  if (segments?.length) {
    const scaledValue = (clamp(value) / 100) * segments.length;
    const fullCount = Math.floor(scaledValue);
    const partialFill = scaledValue - fullCount;
    segments.forEach((segment, index) => {
      const isFull = index < fullCount;
      const isPartial = index === fullCount && partialFill > 0.001;
      segment.classList.toggle('is-active', isFull || isPartial);
      segment.classList.toggle('is-partial', isPartial);
      segment.classList.toggle('is-warning', warning);
      segment.classList.toggle('is-danger', danger);
      if (isPartial) {
        segment.setAttribute('stroke-dasharray', `${(partialFill * 100).toFixed(2)} 100`);
      } else {
        segment.removeAttribute('stroke-dasharray');
      }
    });
  }
}

function setVehicleNitro(value, animate = true) {
  const nitro = Math.round(clamp(value));
  vehicleUi.nitroRing.style.strokeDashoffset = String(100 - nitro);
  if (vehicleUi.raceNitroValue) vehicleUi.raceNitroValue.textContent = String(nitro);
  vehicleUi.nitroGauge.setAttribute('aria-label', translate('nitro_percent', nitro));
  vehicleUi.nitroGauge.classList.toggle('is-low', nitro > 10 && nitro <= 35);
  vehicleUi.nitroGauge.classList.toggle('is-critical', nitro <= 10);

  if (animate && lastNitroValue !== null && nitro !== lastNitroValue) {
    vehicleUi.nitroGauge.classList.add('is-changing');
    window.clearTimeout(nitroChangeTimer);
    nitroChangeTimer = window.setTimeout(() => {
      vehicleUi.nitroGauge.classList.remove('is-changing');
    }, 520);
  }
  lastNitroValue = nitro;
}

function resetVehicleIndicators() {
  fields.speed.textContent = '000';
  fields.gear.textContent = 'N';
  fields.fuel.textContent = '0';
  fields.engine.textContent = '0';

  vehicleUi.gearPrevious.textContent = '';
  vehicleUi.gearPrevious.classList.remove('is-leaving-left', 'is-leaving-right');
  fields.gear.classList.remove('is-entering-right', 'is-entering-left');
  setVehicleRpm(0);
  setVehicleMeter(vehicleUi.fuelBar, 0);
  setVehicleMeter(vehicleUi.engineBar, 0);

  vehicleUi.detailNitro.classList.add('is-hidden');
  vehicleDetailPanel.classList.remove('has-nitro');
  vehicleUi.detailNitroValue.textContent = '0';
  vehicleUi.nitroRing.style.strokeDashoffset = '100';
  if (vehicleUi.raceNitroValue) vehicleUi.raceNitroValue.textContent = '0';

  resetVehicleSafetySlot();
  renderSafetySlot();
}

function getSafetySlotFallback() {
  if (vehicleSafetyState.seatbeltAvailable && vehicleSafetyState.seatbelt !== true) return 'seatbelt';
  if (vehicleSafetyState.hasNitro && vehicleSafetyState.nitro > 0) return 'nitro';
  if (vehicleSafetyState.seatbeltAvailable) return 'seatbelt';
  return null;
}

function renderSafetySlot() {
  if (activeRaceMode === true) {
    const showNitro = vehicleSafetyState.hasNitro;
    vehicleUi.nitroGauge.classList.remove('is-safety-hidden');
    vehicleUi.nitroGauge.classList.toggle('is-disabled', !showNitro);
    vehicleUi.nitroGauge.classList.remove(
      'is-seatbelt',
      'is-unbuckled',
      'is-slot-to-nitro',
      'is-slot-to-seatbelt'
    );
    vehicleUi.nitroGauge.setAttribute('aria-label', translate('nitro_percent', vehicleSafetyState.nitro));
    return;
  }

  const showNitro = safetySlotOwner === 'nitro' && vehicleSafetyState.hasNitro;
  const showSeatbelt = safetySlotOwner === 'seatbelt' && vehicleSafetyState.seatbeltAvailable;

  vehicleUi.nitroGauge.classList.remove('is-disabled');
  vehicleUi.nitroGauge.classList.toggle('is-safety-hidden', !showNitro && !showSeatbelt);
  vehicleUi.nitroGauge.classList.toggle('is-seatbelt', showSeatbelt);
  vehicleUi.nitroGauge.classList.toggle('is-unbuckled', showSeatbelt && vehicleSafetyState.seatbelt !== true);

  if (showSeatbelt) {
    vehicleUi.nitroGauge.setAttribute(
      'aria-label',
      translate(vehicleSafetyState.seatbelt === true ? 'seatbelt_on' : 'seatbelt_off')
    );
  } else if (showNitro) {
    vehicleUi.nitroGauge.setAttribute('aria-label', translate('nitro_percent', vehicleSafetyState.nitro));
  }
}

function renderRaceSeatbelt() {
  if (!vehicleUi.raceSeatbelt) return;

  const available = vehicleSafetyState.seatbeltAvailable === true;
  const buckled = vehicleSafetyState.seatbelt === true;
  vehicleUi.raceSeatbelt.classList.toggle('is-unavailable', !available);
  vehicleUi.raceSeatbelt.classList.toggle('is-buckled', available && buckled);
  vehicleUi.raceSeatbelt.classList.toggle('is-unbuckled', available && !buckled);
  vehicleUi.raceSeatbelt.setAttribute('aria-hidden', String(activeRaceMode !== true || !available));

  if (available) {
    vehicleUi.raceSeatbelt.setAttribute('aria-label', translate(buckled ? 'seatbelt_on' : 'seatbelt_off'));
  }
}

function clearSafetySlotTransition() {
  window.clearTimeout(safetySlotTransitionTimer);
  safetySlotTransitionTimer = null;
  vehicleUi.nitroGauge.classList.remove('is-slot-to-nitro', 'is-slot-to-seatbelt');
}

function transitionSafetySlot(owner) {
  clearSafetySlotTransition();

  if (owner === safetySlotOwner) {
    safetySlotOwner = owner;
    renderSafetySlot();
    return;
  }

  const transitionClass = owner === 'seatbelt' ? 'is-slot-to-seatbelt' : 'is-slot-to-nitro';
  vehicleUi.nitroGauge.classList.add(transitionClass);
  safetySlotTransitionTimer = window.setTimeout(() => {
    safetySlotTransitionTimer = null;
    safetySlotOwner = owner;
    renderSafetySlot();
    vehicleUi.nitroGauge.classList.remove(transitionClass);
  }, SAFETY_SLOT_SWITCH_MS);
}

function selectSafetySlot(owner, holdMs = 0) {
  window.clearTimeout(safetySlotTimer);
  clearSafetySlotTransition();
  safetySlotTimer = null;
  const switchingToSeatbelt = safetySlotOwner === 'nitro'
    && owner === 'seatbelt'
    && vehicleSafetyState.hasNitro
    && vehicleSafetyState.seatbeltAvailable;

  if (switchingToSeatbelt) transitionSafetySlot(owner);
  else {
    safetySlotOwner = owner;
    renderSafetySlot();
  }

  if (holdMs > 0) {
    safetySlotTimer = window.setTimeout(() => {
      safetySlotTimer = null;
      const fallbackOwner = getSafetySlotFallback();
      const returningToNitro = safetySlotOwner === 'seatbelt'
        && fallbackOwner === 'nitro'
        && vehicleSafetyState.seatbelt === true;

      if (returningToNitro) transitionSafetySlot(fallbackOwner);
      else {
        safetySlotOwner = fallbackOwner;
        renderSafetySlot();
      }
    }, holdMs + (switchingToSeatbelt ? SAFETY_SLOT_SWITCH_MS : 0));
  }
}

function resetVehicleSafetySlot() {
  window.clearTimeout(safetySlotTimer);
  window.clearTimeout(nitroChangeTimer);
  window.clearTimeout(nitroEmptyAttemptTimer);
  safetySlotTimer = null;
  nitroChangeTimer = null;
  nitroEmptyAttemptTimer = null;
  clearSafetySlotTransition();
  nitroEmptyAttemptAnimation?.cancel();
  nitroEmptyAttemptAnimation = null;
  safetySlotOwner = null;
  lastNitroValue = null;
  lastSeatbeltState = null;
  lastNitroActive = false;
  lastHadNitro = false;
  app.classList.remove('is-nitro-active');
  vehicleSafetyState = {
    hasNitro: false,
    nitro: 0,
    seatbelt: false,
    seatbeltAvailable: false
  };
  renderRaceSeatbelt();
  vehicleUi.nitroGauge.classList.remove(
    'is-changing',
    'is-empty-attempt',
    'is-low',
    'is-critical',
    'is-disabled',
    'is-seatbelt',
    'is-unbuckled'
  );
}

function animateEmptyNitroAttempt() {
  if (!vehicleMode || !vehicleSafetyState.hasNitro || vehicleSafetyState.nitro > 0) return;

  nitroEmptyAttemptAnimation?.cancel();
  window.clearTimeout(nitroEmptyAttemptTimer);
  selectSafetySlot('nitro', EMPTY_NITRO_SLOT_HOLD_MS);
  vehicleUi.nitroGauge.classList.remove('is-empty-attempt');
  void vehicleUi.nitroGauge.offsetWidth;
  vehicleUi.nitroGauge.classList.add('is-empty-attempt');

  nitroEmptyAttemptAnimation = vehicleUi.nitroRing.animate([
    { strokeDashoffset: '100' },
    { strokeDashoffset: '0', offset: 0.38 },
    { strokeDashoffset: '100' }
  ], {
    duration: 900,
    easing: 'ease-in-out'
  });

  nitroEmptyAttemptTimer = window.setTimeout(() => {
    vehicleUi.nitroGauge.classList.remove('is-empty-attempt');
    nitroEmptyAttemptAnimation = null;
  }, 900);
}

function setVehicleSafety(nitroValue, seatbelt, seatbeltAvailable = true, nitroActive = false) {
  const hasNitro = nitroValue !== false && nitroValue !== null && nitroValue !== undefined;
  const nitro = hasNitro ? Math.round(clamp(nitroValue)) : 0;
  const previousNitro = lastNitroValue;
  const seatbeltChanged = lastSeatbeltState !== null && lastSeatbeltState !== (seatbelt === true);
  const nitroChanged = hasNitro && previousNitro !== null && nitro !== previousNitro;
  const nitroStarted = nitroActive === true && lastNitroActive !== true;
  const nitroInstalled = hasNitro && lastHadNitro !== true;
  const nitroDepleted = hasNitro && previousNitro !== null && previousNitro > 0 && nitro <= 0;

  vehicleSafetyState = {
    hasNitro,
    nitro,
    seatbelt: seatbelt === true,
    seatbeltAvailable: seatbeltAvailable === true
  };
  app.classList.toggle('is-nitro-active', hasNitro && nitro > 0 && nitroActive === true);
  renderRaceSeatbelt();

  if (hasNitro) {
    setVehicleNitro(nitro);
  } else {
    window.clearTimeout(nitroChangeTimer);
    nitroChangeTimer = null;
    vehicleUi.nitroGauge.classList.remove('is-changing', 'is-low', 'is-critical');
    lastNitroValue = null;
  }

  lastSeatbeltState = seatbelt === true;
  lastNitroActive = nitroActive === true;
  lastHadNitro = hasNitro;

  if (activeRaceMode === true) {
    window.clearTimeout(safetySlotTimer);
    safetySlotTimer = null;
    clearSafetySlotTransition();
    safetySlotOwner = getSafetySlotFallback();
    renderSafetySlot();
    return;
  }

  if (seatbeltChanged && seatbeltAvailable === true) {
    selectSafetySlot(
      'seatbelt',
      seatbelt === true && hasNitro && nitro > 0 ? BUCKLED_SLOT_HOLD_MS : 0
    );
    return;
  }

  if (nitroDepleted) {
    selectSafetySlot('nitro', EMPTY_NITRO_SLOT_HOLD_MS);
    return;
  }

  if (hasNitro && nitro > 0 && (nitroInstalled || nitroStarted || nitroChanged)) {
    selectSafetySlot('nitro', NITRO_SLOT_HOLD_MS);
    return;
  }

  const ownerUnavailable = (safetySlotOwner === 'nitro' && !hasNitro)
    || (safetySlotOwner === 'seatbelt' && seatbeltAvailable !== true);
  const emptyNitroWithoutHold = safetySlotOwner === 'nitro' && nitro <= 0 && safetySlotTimer === null;

  if (safetySlotOwner === null || ownerUnavailable || emptyNitroWithoutHold) {
    selectSafetySlot(getSafetySlotFallback());
  } else {
    renderSafetySlot();
  }
}

function resetVehicleCrashEffect() {
  window.clearTimeout(vehicleCrashEffectTimer);
  vehicleCrashEffectTimer = null;
  app.classList.remove('is-vehicle-crash-reboot');
}

function animateSummaryLayout(previousRect) {
  summaryLayoutTransition?.cancel();
  summaryLayoutTransition = null;
  if (!identitySummary || !previousRect || window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return;

  const nextRect = identitySummary.getBoundingClientRect();
  if (!nextRect.width || !nextRect.height) return;

  const offsetX = previousRect.left - nextRect.left;
  const offsetY = previousRect.top - nextRect.top;
  const scaleX = previousRect.width / nextRect.width;
  const scaleY = previousRect.height / nextRect.height;
  if (Math.abs(offsetX) < 0.5 && Math.abs(offsetY) < 0.5
    && Math.abs(scaleX - 1) < 0.01 && Math.abs(scaleY - 1) < 0.01) return;

  summaryLayoutTransition = identitySummary.animate([
    { translate: `${offsetX}px ${offsetY}px`, scale: `${scaleX} ${scaleY}` },
    { translate: `${offsetX * 0.12}px ${offsetY * 0.12}px`, scale: '1 1', offset: 0.78 },
    { translate: '0 0', scale: '1 1' }
  ], {
    duration: 680,
    easing: 'cubic-bezier(0.16, 1, 0.3, 1)'
  });
  summaryLayoutTransition.addEventListener('finish', () => {
    summaryLayoutTransition = null;
  }, { once: true });
}

function animateVoiceLayout(previousRect) {
  voiceLayoutTransition?.cancel();
  voiceLayoutTransition = null;
  if (!voiceIndicator || !previousRect || window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return;

  const nextRect = voiceIndicator.getBoundingClientRect();
  if (!nextRect.width || !nextRect.height) return;

  const offsetX = previousRect.left - nextRect.left;
  const offsetY = previousRect.top - nextRect.top;
  const scaleX = previousRect.width / nextRect.width;
  const scaleY = previousRect.height / nextRect.height;
  if (Math.abs(offsetX) < 0.5 && Math.abs(offsetY) < 0.5
    && Math.abs(scaleX - 1) < 0.01 && Math.abs(scaleY - 1) < 0.01) return;

  voiceLayoutTransition = voiceIndicator.animate([
    { translate: `${offsetX}px ${offsetY}px`, scale: `${scaleX} ${scaleY}` },
    { translate: `${offsetX * 0.12}px ${offsetY * 0.12}px`, scale: '1 1', offset: 0.78 },
    { translate: '0 0', scale: '1 1' }
  ], {
    duration: 680,
    easing: 'cubic-bezier(0.16, 1, 0.3, 1)'
  });
  voiceLayoutTransition.addEventListener('finish', () => {
    voiceLayoutTransition = null;
  }, { once: true });
}

function refreshStatusThresholds() {
  STATUS_ORDER.forEach((name) => {
    const status = statuses[name];
    const value = status?.lastValue;
    if (!Number.isFinite(value)) return;
    updateStatus(name, value, false);
  });
  syncCriticalStatusState();
}

function playVehicleCrashEffect() {
  if (!vehicleMode || vehicleExiting || !vehicleRevealReady) return;

  resetVehicleCrashEffect();
  void vehiclePanel.offsetWidth;
  app.classList.add('is-vehicle-crash-reboot');
  vehicleCrashEffectTimer = window.setTimeout(() => {
    vehicleCrashEffectTimer = null;
    app.classList.remove('is-vehicle-crash-reboot');
  }, VEHICLE_CRASH_EFFECT_MS);
}

function updateVehicle(vehicle) {
  const nextVehicleMode = Boolean(vehicle);
  const emergencyLightsActive = nextVehicleMode
    && (vehicle.emergencyLights === true || Number(vehicle.emergencyLights) === 1);
  app.classList.toggle('is-emergency-lights', emergencyLightsActive);
  if (!nextVehicleMode) resetVehicleCrashEffect();

  if (nextVehicleMode && vehicleExiting) {
    window.clearTimeout(vehicleExitTimer);
    vehicleExitTimer = null;
    vehicleExiting = false;
    app.classList.remove('is-vehicle-exiting', 'is-foot-handoff');
  }

  if (!nextVehicleMode && vehicleMode) {
    if (!vehicleExiting) {
      vehicleExiting = true;
      window.clearTimeout(vehicleRevealDelayTimer);
      window.clearTimeout(vehicleEntryTimer);
      vehicleRevealDelayTimer = null;
      vehicleEntryTimer = null;
      app.classList.remove('is-vehicle-reveal-pending', 'is-vehicle-entering');
      app.classList.add('is-vehicle-exiting', 'is-foot-handoff');
      vehicleExitTimer = window.setTimeout(() => {
        const summaryStartRect = identitySummary?.getBoundingClientRect();
        const voiceStartRect = voiceIndicator?.getBoundingClientRect();
        vehicleExitTimer = null;
        vehicleExiting = false;
        vehicleMode = false;
        vehicleRevealReady = false;
        app.classList.remove('is-vehicle', 'is-vehicle-exiting', 'is-foot-handoff');
        refreshStatusThresholds();
        animateSummaryLayout(summaryStartRect);
        animateVoiceLayout(voiceStartRect);
        vehiclePanel.classList.add('is-hidden');
        vehicleDetailPanel.classList.add('is-hidden');
        resetVehicleSafetySlot();
        scheduleTopStatusAnchor();
      }, 780);
    }
    return false;
  }

  const modeChanged = nextVehicleMode !== vehicleMode;

  if (nextVehicleMode && (modeChanged || vehicle.initializing === true)) {
    resetVehicleIndicators();
  }

  if (modeChanged) {
    clearTransientStatusRows();
    window.clearTimeout(showAllExitTimer);
    window.clearTimeout(modeSwitchTimer);
    window.clearTimeout(vehicleEntryTimer);
    window.clearTimeout(vehicleRevealDelayTimer);
    window.clearTimeout(vehicleExitTimer);
    window.clearTimeout(identityHandoffTimer);
    window.clearTimeout(summaryHandoffTimer);
    vehicleExitTimer = null;
    vehicleExiting = false;
    identityHandoffTimer = null;
    summaryHandoffTimer = null;
    showAllExitTimer = null;
    showAllStatuses = false;
    modeSwitching = true;
    app.classList.remove('show-status-values', 'is-status-exiting');
    app.classList.remove('is-foot-handoff', 'is-vehicle-handoff', 'is-summary-handoff');
    app.classList.add('is-mode-switching');
    modeSwitchTimer = window.setTimeout(() => {
      modeSwitching = false;
      modeSwitchTimer = null;
      app.classList.remove('is-mode-switching');
    }, MODE_SWITCH_MS);
  }

  const summaryStartRect = modeChanged ? identitySummary?.getBoundingClientRect() : null;
  const voiceStartRect = modeChanged ? voiceIndicator?.getBoundingClientRect() : null;
  vehicleMode = nextVehicleMode;
  app.classList.toggle('is-vehicle', nextVehicleMode);
  if (modeChanged && nextVehicleMode) refreshStatusThresholds();
  if (modeChanged && nextVehicleMode) {
    animateSummaryLayout(summaryStartRect);
    animateVoiceLayout(voiceStartRect);
  }

  if (modeChanged) {
    app.classList.remove('is-vehicle-entering', 'is-vehicle-reveal-pending');
    if (nextVehicleMode) {
      vehicleRevealReady = false;
      app.classList.add('is-vehicle-reveal-pending', 'is-vehicle-handoff');
      identityHandoffTimer = window.setTimeout(() => {
        identityHandoffTimer = null;
        app.classList.remove('is-vehicle-handoff');
      }, 920);
      summaryHandoffTimer = window.setTimeout(() => {
        app.classList.add('is-summary-handoff');
        summaryHandoffTimer = window.setTimeout(() => {
          summaryHandoffTimer = null;
          app.classList.remove('is-summary-handoff');
        }, 820);
      }, 680);
      vehicleRevealDelayTimer = window.setTimeout(() => {
        vehicleRevealReady = true;
        vehicleRevealDelayTimer = null;
        app.classList.add('is-vehicle-entering');
        vehiclePanel.classList.remove('is-hidden');
        vehicleDetailPanel.classList.remove('is-hidden');
        app.classList.remove('is-vehicle-reveal-pending');
        vehicleEntryTimer = window.setTimeout(() => {
          app.classList.remove('is-vehicle-entering');
          vehicleEntryTimer = null;
        }, 900);
      }, 450);
    } else {
      vehicleRevealReady = false;
      vehicleRevealDelayTimer = null;
      vehicleEntryTimer = null;
    }
  }

  if (!vehicle || !vehicleRevealReady) {
    vehiclePanel.classList.add('is-hidden');
    vehicleDetailPanel.classList.add('is-hidden');
    if (!vehicle) resetVehicleSafetySlot();
    return modeChanged;
  }

  vehiclePanel.classList.remove('is-hidden');
  vehicleDetailPanel.classList.remove('is-hidden');

  const fuel = Math.round(clamp(vehicle.fuel));
  const engine = Math.round(clamp(vehicle.engine));
  const hasNitro = vehicle.nitro !== false && vehicle.nitro !== null && vehicle.nitro !== undefined;

  fields.speed.textContent = String(Math.max(0, Math.round(vehicle.speed || 0))).padStart(3, '0');
  setVehicleGear(vehicle.gear || 'N');
  setVehicleRpm(vehicle.rpm);
  fields.fuel.textContent = fuel;
  fields.engine.textContent = engine;
  vehicleUi.detailNitro.classList.toggle('is-hidden', !hasNitro);
  vehicleDetailPanel.classList.toggle('has-nitro', hasNitro);
  vehicleUi.detailNitroValue.textContent = String(hasNitro ? Math.round(clamp(vehicle.nitro)) : 0);
  setVehicleMeter(vehicleUi.fuelBar, fuel);
  setVehicleMeter(vehicleUi.engineBar, engine);
  setVehicleSafety(vehicle.nitro, vehicle.seatbelt, vehicle.seatbeltAvailable, vehicle.nitroActive);
  return modeChanged;
}

function update(patch) {
  if (!patch || typeof patch !== 'object') return;
  hudState = mergeState(hudState, patch);

  if (Object.hasOwn(patch, 'visible')) setVisible(patch.visible !== false);
  if (Object.hasOwn(patch, 'hudPosition')) setHudPosition(patch.hudPosition);

  let modeChanged = false;
  if (Object.hasOwn(patch, 'vehicle')) modeChanged = updateVehicle(hudState.vehicle);
  if (Object.hasOwn(patch, 'minimalMode') || Object.hasOwn(patch, 'ultraMinimalMode')) {
    hudConfig.minimalMode = Boolean(patch.minimalMode ?? hudConfig.minimalMode);
    hudConfig.ultraMinimalMode = Boolean(patch.ultraMinimalMode ?? hudConfig.ultraMinimalMode);
    applyFootDisplayMode();
  }
  if (Object.hasOwn(patch, 'showAllStatuses')) {
    app.classList.toggle('is-peeking', Boolean(patch.showAllStatuses) && !modeSwitching);
    const normalMode = !app.classList.contains('is-minimal');
    setShowAllStatuses(normalMode || (Boolean(patch.showAllStatuses) && !modeSwitching));
  }

  const hasStatusPatch = STATUS_ORDER.some((name) => Object.hasOwn(patch, name));
  if (Object.hasOwn(patch, 'health')) updateStatus('health', patch.health, !modeChanged);
  if (Object.hasOwn(patch, 'armour')) updateStatus('armour', patch.armour, !modeChanged);
  if (Object.hasOwn(patch, 'stamina')) updateStatus('stamina', patch.stamina, !modeChanged);
  if (Object.hasOwn(patch, 'oxygen')) updateStatus('oxygen', patch.oxygen, !modeChanged);
  if (Object.hasOwn(patch, 'hunger')) updateStatus('hunger', patch.hunger, !modeChanged);
  if (Object.hasOwn(patch, 'thirst')) updateStatus('thirst', patch.thirst, !modeChanged);
  if (hasStatusPatch) syncCriticalStatusState();

  if (Object.hasOwn(patch, 'temporaryId') || Object.hasOwn(patch, 'serverId')) {
    const temporaryId = numericId(patch.temporaryId ?? patch.serverId, 10);
    fields.serverId.textContent = temporaryId;
    fields.temporaryId.textContent = temporaryId;
  }
  if (Object.hasOwn(patch, 'permanentId')) {
    fields.permanentId.textContent = numericId(patch.permanentId, hudConfig.identity?.permanentIdMaxLength);
  }
  if (Object.hasOwn(patch, 'time')) fields.time.textContent = patch.time || '00:00';
  if (Object.hasOwn(patch, 'compass')) fields.compass.textContent = patch.compass || 'K';
  if (Object.hasOwn(patch, 'street')) fields.street.textContent = patch.street || translate('locating');
  if (Object.hasOwn(patch, 'area')) fields.area.textContent = patch.area || '';
  if (Object.hasOwn(patch, 'talking')) fields.voice.classList.toggle('is-talking', Boolean(patch.talking));
  if (Object.hasOwn(patch, 'voiceMode')) {
    hudState.voiceMode = setVoiceMode(patch.voiceMode);
  }

  const layoutRelevant = hasStatusPatch
    || Object.hasOwn(patch, 'vehicle')
    || Object.hasOwn(patch, 'minimalMode')
    || Object.hasOwn(patch, 'ultraMinimalMode')
    || Object.hasOwn(patch, 'showAllStatuses')
    || Object.hasOwn(patch, 'temporaryId')
    || Object.hasOwn(patch, 'serverId')
    || Object.hasOwn(patch, 'permanentId');
  if (layoutRelevant) scheduleTopStatusAnchor();
}


settingsVisibility.addEventListener('click', () => sendSettingsAction('toggleVisibility'));
settingsLocation.addEventListener('click', () => sendSettingsAction('toggleLocation'));

settingsModeButtons.forEach((button) => {
  button.addEventListener('click', () => sendSettingsAction('setMode', button.dataset.settingsMode));
});

settingsVehicleModeButtons.forEach((button) => {
  button.addEventListener('click', () => sendSettingsAction('setVehicleMode', button.dataset.settingsVehicleMode));
});

settingsPositionButtons.forEach((button) => {
  button.addEventListener('click', () => sendSettingsAction('setPosition', button.dataset.settingsPosition));
});

settingsPaletteButtons.forEach((button) => {
  button.addEventListener('click', () => sendSettingsAction('setPalette', button.dataset.settingsPalette));
});

if (settingsOpacity) {
  settingsOpacity.addEventListener('input', () => {
    const opacity = setHudOpacity(settingsOpacity.value);
    if (settingsOpacityValue) settingsOpacityValue.textContent = `${opacity}%`;
  });

  settingsOpacity.addEventListener('change', () => {
    sendSettingsAction('setOpacity', normalizeHudOpacity(settingsOpacity.value));
  });
}

settingsPreview.addEventListener('click', () => sendSettingsAction('preview'));
settingsCloseButtons.forEach((button) => {
  button.addEventListener('click', () => sendSettingsAction('close'));
});

window.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape' || settingsPanel.classList.contains('is-hidden')) return;
  event.preventDefault();
  sendSettingsAction('close');
});

const notificationGlyphs = {
  error: '\u00D7',
  warning: '!',
  success: '\u2713',
  inform: 'i',
  info: 'i'
};

const iconGlyphs = {
  'circle-info': 'i',
  'circle-check': '\u2713',
  'triangle-exclamation': '!',
  'circle-xmark': '\u00D7',
  hand: 'E'
};

function updateMarquee(element) {
  if (!element) return;
  element.classList.remove('is-marquee');
  element.style.removeProperty('--marquee-distance');
  element.style.removeProperty('--marquee-duration');

  requestAnimationFrame(() => {
    if (!element.isConnected) return;
    const overflow = Math.ceil(element.scrollWidth - element.clientWidth);
    if (overflow <= 2) return;

    const distance = overflow + 14;
    const duration = Math.max(5.5, Math.min(14, distance / 24 + 3.2));
    element.style.setProperty('--marquee-distance', `${distance}px`);
    element.style.setProperty('--marquee-duration', `${duration.toFixed(2)}s`);
    element.classList.add('is-marquee');
  });
}

function refreshMarquees() {
  hudNotificationRecords.forEach((record) => {
    updateMarquee(record.title);
    updateMarquee(record.description);
  });
  if (hudTextUi?.classList.contains('is-visible')) updateMarquee(hudTextUiText);
}

function removeHudNotification(key, immediate = false) {
  const record = hudNotificationRecords.get(String(key));
  if (!record) return;
  window.clearTimeout(record.timer);
  hudNotificationRecords.delete(String(key));
  const finish = () => {
    record.card.remove();
    if (!hudNotificationRecords.size) app.classList.remove('has-hud-notifications');
    scheduleTopStatusAnchor();
  };
  if (immediate) finish();
  else {
    record.title.classList.remove('is-marquee');
    record.description.classList.remove('is-marquee');
    record.card.classList.remove('is-visible');
    record.card.classList.add('is-leaving');
    window.setTimeout(finish, STATUS_EXIT_MS);
  }
}

function showHudNotification(raw = {}) {
  if (!hudNotifications) return;
  const key = String(raw.key || raw.id || `anonymous-${Date.now()}-${Math.random()}`);
  const existing = hudNotificationRecords.get(key);
  const requestedType = String(raw.type || 'inform').toLowerCase();
  const type = Object.hasOwn(notificationGlyphs, requestedType) ? requestedType : 'inform';
  const record = existing || {};
  const card = record.card || document.createElement('article');
  const icon = record.icon || document.createElement('div');
  const copy = record.copy || document.createElement('div');
  const title = record.title || document.createElement('strong');
  const description = record.description || document.createElement('span');

  card.className = `hud-notification hud-notification-${type}${existing ? ' is-visible' : ''}`;
  card.dataset.notificationId = key;
  icon.className = 'hud-notification-icon';
  icon.textContent = iconGlyphs[String(raw.icon)] || notificationGlyphs[type];
  icon.style.color = /^#[0-9a-f]{6}$/i.test(String(raw.iconColor || '')) ? raw.iconColor : '';
  copy.className = 'hud-notification-copy';
  title.textContent = String(raw.title || translate('notification'));
  description.textContent = String(raw.description || '');

  if (!existing) {
    copy.append(title, description);
    card.append(icon, copy);
    hudNotifications.prepend(card);
  }
  app.classList.add('has-hud-notifications');

  const duration = Math.min(60000, Math.max(250, Number(raw.duration) || 5000));
  const deadline = existing && !raw.restartDuration ? existing.deadline : Date.now() + duration;
  window.clearTimeout(existing?.timer);
  Object.assign(record, { card, icon, copy, title, description, deadline });
  record.timer = window.setTimeout(() => removeHudNotification(key), Math.max(0, deadline - Date.now()));
  hudNotificationRecords.set(key, record);
  if (!existing) requestAnimationFrame(() => card.classList.add('is-visible'));
  updateMarquee(title);
  updateMarquee(description);

  const safetyLimit = Math.min(500, Math.max(10, Number(hudConfig.notificationSafetyLimit) || 100));
  while (hudNotificationRecords.size > safetyLimit) {
    const oldest = hudNotifications.lastElementChild;
    if (!oldest) break;
    removeHudNotification(oldest.dataset.notificationId, true);
  }
  scheduleTopStatusAnchor();
}

function resetHudNotifications() {
  hudNotificationRecords.forEach((record) => window.clearTimeout(record.timer));
  hudNotificationRecords.clear();
  if (hudNotifications) hudNotifications.replaceChildren();
  app.classList.remove('has-hud-notifications');
  scheduleTopStatusAnchor();
}

function showHudTextUi(raw = {}) {
  if (!hudTextUi) return;
  const visible = raw.visible === true;
  hudTextUi.classList.toggle('is-visible', visible);
  hudTextUiIcon.textContent = iconGlyphs[String(raw.icon)] || iconGlyphs.hand;
  const iconColor = /^#[0-9a-f]{6}$/i.test(String(raw.iconColor || '')) ? raw.iconColor : 'var(--theme-accent)';
  hudTextUi.style.setProperty('--textui-color', iconColor);
  hudTextUiIcon.style.color = '';
  hudTextUiText.textContent = String(raw.text || '');
  if (visible) updateMarquee(hudTextUiText);
  else hudTextUiText.classList.remove('is-marquee');
}

const activeVehicleSounds = new Set();

function playVehicleSound(raw = {}) {
  const file = String(raw.file || '');
  if (!/^sounds\/[a-z0-9._/-]+\.(ogg|mp3|wav)$/i.test(file) || file.includes('..')) return;

  const audio = new Audio(file);
  audio.volume = Math.min(1, Math.max(0, Number(raw.volume) || 0));
  activeVehicleSounds.add(audio);

  const release = () => activeVehicleSounds.delete(audio);
  audio.addEventListener('ended', release, { once: true });
  audio.addEventListener('error', release, { once: true });
  audio.play().catch(release);
}

function resetRuntimeState() {
  clearSettingsActionQueue();

  [
    showAllExitTimer,
    modeSwitchTimer,
    vehicleEntryTimer,
    vehicleRevealDelayTimer,
    vehicleExitTimer,
    identityHandoffTimer,
    summaryHandoffTimer,
    raceModeSwitchTimer
  ].forEach((timer) => window.clearTimeout(timer));

  showAllExitTimer = null;
  modeSwitchTimer = null;
  vehicleEntryTimer = null;
  vehicleRevealDelayTimer = null;
  vehicleExitTimer = null;
  identityHandoffTimer = null;
  summaryHandoffTimer = null;
  raceModeSwitchTimer = null;

  summaryLayoutTransition?.cancel();
  voiceLayoutTransition?.cancel();
  summaryLayoutTransition = null;
  voiceLayoutTransition = null;

  if (statusAnchorFrame !== null) window.cancelAnimationFrame(statusAnchorFrame);
  statusAnchorFrame = null;

  STATUS_ORDER.forEach((name) => {
    const status = statuses[name];
    window.clearTimeout(status.changeTimer);
    window.clearTimeout(status.exitTimer);
    window.clearTimeout(status.dropTimer);
    status.changeTimer = null;
    status.exitTimer = null;
    status.dropTimer = null;
    status.lastValue = undefined;
    status.card.classList.add('is-hidden');
    status.card.classList.remove(
      'is-changing',
      'is-leaving',
      'is-resuming',
      'is-critical',
      'is-top-status'
    );
    status.card.style.removeProperty('--critical-pulse-delay');
    status.card.style.removeProperty('--status-anchor-x');
    status.card.style.removeProperty('--deploy-delay');
    status.card.style.removeProperty('--exit-delay');
    status.summary?.parentElement?.classList.add('is-hidden');
    status.summary?.parentElement?.classList.remove('is-critical', 'is-dropping', 'is-empty');
    status.summary?.style.removeProperty('--summary-progress');
  });

  showAllStatuses = false;
  modeSwitching = false;
  vehicleMode = false;
  vehicleRevealReady = false;
  vehicleExiting = false;
  activeRaceMode = null;

  app.classList.remove(
    'show-status-values',
    'is-status-exiting',
    'is-peeking',
    'has-critical-status',
    'has-status-changing',
    'has-status-leaving',
    'is-mode-switching',
    'is-vehicle',
    'is-vehicle-entering',
    'is-vehicle-exiting',
    'is-vehicle-reveal-pending',
    'is-vehicle-handoff',
    'is-foot-handoff',
    'is-summary-handoff',
    'is-race-mode',
    'is-emergency-lights'
  );
  vehiclePanel.classList.add('is-hidden');
  vehiclePanel.classList.remove('is-race-switching-out', 'is-race-switching-in');
  vehicleDetailPanel.classList.add('is-hidden');
  vehicleDetailPanel.classList.remove('has-nitro');
  resetVehicleCrashEffect();
  resetVehicleSafetySlot();
}

window.addEventListener('message', (event) => {
  const payload = event.data;
  if (!payload || typeof payload !== 'object') return;

  const data = payload.data && typeof payload.data === 'object' ? payload.data : {};

  if (payload.action === 'hud:notification:add' || payload.action === 'hud:notification:update'
      || payload.action === 'hud:notification' || payload.action === 'hudNotification') {
    showHudNotification(data);
    return;
  }
  if (payload.action === 'hud:notification:remove') {
    removeHudNotification(data.key || data.id);
    return;
  }
  if (payload.action === 'hud:notification:reset') {
    resetHudNotifications();
    return;
  }
  if (payload.action === 'hud:textui') {
    showHudTextUi(data);
    return;
  }
  if (payload.action === 'hud:vehicleSound') {
    playVehicleSound(data);
    return;
  }
  if (payload.action === 'hud:nitroEmptyAttempt') {
    animateEmptyNitroAttempt();
    return;
  }
  if (payload.action === 'hud:vehicleCrash') {
    playVehicleCrashEffect();
    return;
  }

  if (payload.action === 'hud:visibility' || payload.action === 'visibility') {
    setVisible({ ...data, visible: data.visible ?? payload.visible });
    return;
  }

  if (payload.action === 'hud:locale') {
    applyLocale(data.strings, data.language);
    return;
  }

  if (payload.action === 'hud:config') {
    applyConfig(data);
    return;
  }

  if (payload.action === 'hud:settings' || payload.action === 'settings') {
    setSettingsVisible(Boolean(data.open ?? payload.open), data.state ?? payload.data);
    return;
  }

  if (payload.action === 'hud:reset') {
    resetRuntimeState();
    activeVehicleSounds.forEach((audio) => {
      audio.pause();
      audio.currentTime = 0;
    });
    activeVehicleSounds.clear();
    resetHudNotifications();
    hudState = { ...DEFAULT_HUD_STATE };
    setVoiceMode(DEFAULT_HUD_STATE.voiceMode);
    app.classList.remove('has-critical-status');
    setVisible({ panelsVisible: false, notificationsVisible: false, textUiVisible: false });
    showHudTextUi({ visible: false });
    setSettingsVisible(false);
    return;
  }

  if (payload.action === 'minimalMode') {
    hudConfig.minimalMode = Boolean(payload.enabled);
    hudConfig.ultraMinimalMode = false;
    applyFootDisplayMode();
    return;
  }

  if (payload.action === 'ultraMinimalMode') {
    hudConfig.ultraMinimalMode = Boolean(payload.enabled);
    if (hudConfig.ultraMinimalMode) hudConfig.minimalMode = false;
    applyFootDisplayMode();
    return;
  }

  if (payload.action === 'position') {
    setHudPosition(payload.position);
    return;
  }

  if ((payload.action === 'hud:update' || payload.action === 'update') && data) {
    update(data);
  }
});

async function signalHudReady() {
  try {
    await fetch(`https://${GetParentResourceName()}/hudReady`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: '{}'
    });
  } catch (error) {
    window.setTimeout(signalHudReady, 500);
  }
}

window.requestAnimationFrame(signalHudReady);
