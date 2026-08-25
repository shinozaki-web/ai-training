(function () {
  'use strict';

  const STORAGE_KEY = 'ai-biztraining-local-v1';

  function emptyState() {
    return {
      profile: { name: '受講者', company: '' },
      progress: {},
      badges: {},
      quizResults: []
    };
  }

  function load() {
    try {
      const value = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null');
      return value && typeof value === 'object'
        ? { ...emptyState(), ...value }
        : emptyState();
    } catch (_) {
      return emptyState();
    }
  }

  function save(state) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  }

  window.trainingStore = {
    getProfile() {
      return load().profile;
    },
    setProfile(profile) {
      const state = load();
      state.profile = {
        name: String(profile?.name || '受講者').slice(0, 60),
        company: String(profile?.company || '').slice(0, 100)
      };
      save(state);
    },
    getProgressMap() {
      const progress = load().progress;
      const result = {};
      Object.entries(progress).forEach(([moduleId, sectionIds]) => {
        result[Number(moduleId)] = new Set(Array.isArray(sectionIds) ? sectionIds : []);
      });
      return result;
    },
    getCompletedSections(moduleId) {
      const values = load().progress[String(moduleId)];
      return new Set(Array.isArray(values) ? values : []);
    },
    completeSection(moduleId, sectionId) {
      const state = load();
      const key = String(moduleId);
      const completed = new Set(Array.isArray(state.progress[key]) ? state.progress[key] : []);
      completed.add(sectionId);
      state.progress[key] = Array.from(completed);
      save(state);
    },
    getBadges() {
      return { ...load().badges };
    },
    awardBadge(badgeId) {
      const state = load();
      if (!state.badges[badgeId]) state.badges[badgeId] = new Date().toISOString();
      save(state);
    },
    saveQuizResult(moduleId, score, total) {
      const state = load();
      state.quizResults.push({ moduleId, score, total, completedAt: new Date().toISOString() });
      state.quizResults = state.quizResults.slice(-100);
      save(state);
    }
  };
})();
