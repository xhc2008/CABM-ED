<template>
  <div class="sidebar-container">
    <!-- 切换按钮 -->
    <button 
      class="toggle-btn" 
      @click="$emit('toggle')"
      :class="{ 'open': isOpen }"
    >
      {{ isOpen ? '◀' : '▶' }}
    </button>

    <!-- 侧边栏内容 -->
    <div class="sidebar" :class="{ 'open': isOpen }">
      <!-- 时钟 -->
      <div class="clock-section">
        <Clock />
      </div>

      <!-- 自动模式开关 -->
      <div class="auto-mode-section">
        <label class="auto-toggle">
          <input 
            type="checkbox" 
            :checked="autoMode"
            @change="$emit('toggleAuto')"
          />
          <span class="toggle-label">自动模式</span>
          <span class="toggle-hint">根据当前时间自动切换</span>
        </label>
      </div>

      <!-- 场景选择 -->
      <div class="control-section">
        <h3>场景</h3>
        <div class="button-group">
          <button
            v-for="scene in scenes"
            :key="scene.id"
            @click="$emit('selectScene', scene.id)"
            class="control-btn"
            :class="{ 'active': currentSceneId === scene.id }"
          >
            {{ scene.name }}
          </button>
        </div>
      </div>

      <!-- 天气选择 -->
      <div class="control-section">
        <h3>天气</h3>
        <div class="button-group">
          <button
            v-for="weather in currentSceneWeathers"
            :key="weather.id"
            @click="$emit('selectWeather', weather.id)"
            class="control-btn"
            :class="{ 'active': currentWeatherId === weather.id }"
          >
            {{ weather.name }}
          </button>
        </div>
      </div>

      <!-- 时间段选择 -->
      <div class="control-section">
        <h3>时间</h3>
        <div class="button-group">
          <button
            v-for="time in currentWeatherTimes"
            :key="time.id"
            @click="$emit('selectTime', time.id)"
            class="control-btn"
            :class="{ 'active': currentTimeId === time.id, 'disabled': autoMode }"
            :disabled="autoMode"
          >
            {{ time.name }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import Clock from './Clock.vue'

const props = defineProps({
  scenes: Array,
  currentSceneId: String,
  currentWeatherId: String,
  currentTimeId: String,
  autoMode: Boolean,
  isOpen: Boolean
})

defineEmits(['toggle', 'selectScene', 'selectWeather', 'selectTime', 'toggleAuto'])

// 当前场景的天气列表
const currentSceneWeathers = computed(() => {
  if (!props.currentSceneId || !props.scenes) return []
  const scene = props.scenes.find(s => s.id === props.currentSceneId)
  return scene?.weathers || []
})

// 当前天气的时间段列表
const currentWeatherTimes = computed(() => {
  if (!props.currentWeatherId) return []
  const weather = currentSceneWeathers.value.find(w => w.id === props.currentWeatherId)
  return weather?.times || []
})
</script>

<style scoped>
.sidebar-container {
  position: fixed;
  left: 0;
  top: 0;
  height: 100%;
  z-index: 1000;
}

.toggle-btn {
  position: absolute;
  left: 0;
  top: 50%;
  transform: translateY(-50%);
  width: 40px;
  height: 80px;
  background: rgba(0, 0, 0, 0.5);
  color: white;
  border: none;
  border-radius: 0 8px 8px 0;
  cursor: pointer;
  font-size: 20px;
  transition: all 0.3s ease;
  z-index: 1001;
}

.toggle-btn.open {
  left: 320px;
}

.toggle-btn:hover {
  background: rgba(0, 0, 0, 0.7);
}

.sidebar {
  position: absolute;
  left: -320px;
  top: 0;
  width: 320px;
  height: 100%;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  transition: left 0.3s ease;
  overflow-y: auto;
  padding: 20px;
  box-shadow: 2px 0 10px rgba(0, 0, 0, 0.1);
}

.sidebar.open {
  left: 0;
}

.clock-section {
  margin-bottom: 20px;
  padding-bottom: 20px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
}

.auto-mode-section {
  margin-bottom: 20px;
  padding-bottom: 20px;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
}

.auto-toggle {
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  user-select: none;
}

.auto-toggle input[type="checkbox"] {
  width: 18px;
  height: 18px;
  cursor: pointer;
}

.toggle-label {
  font-size: 16px;
  font-weight: 500;
  color: #333;
}

.toggle-hint {
  display: block;
  font-size: 12px;
  color: #999;
  margin-left: 28px;
  margin-top: 4px;
}

.control-section {
  margin-bottom: 25px;
}

.control-section h3 {
  font-size: 16px;
  margin-bottom: 12px;
  color: #333;
  font-weight: 600;
}

.button-group {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.control-btn {
  padding: 8px 16px;
  background: rgba(100, 150, 255, 0.1);
  border: 2px solid rgba(100, 150, 255, 0.3);
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s ease;
  font-size: 14px;
  color: #333;
  font-weight: 500;
}

.control-btn:hover:not(.disabled) {
  background: rgba(100, 150, 255, 0.2);
  border-color: rgba(100, 150, 255, 0.5);
  transform: translateY(-1px);
}

.control-btn.active {
  background: rgba(100, 150, 255, 0.3);
  border-color: rgba(100, 150, 255, 0.7);
  color: #0056d6;
}

.control-btn.disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 移动端适配 */
@media (max-width: 768px) {
  .sidebar {
    width: 280px;
    left: -280px;
  }
  
  .toggle-btn.open {
    left: 280px;
  }
  
  .toggle-btn {
    width: 35px;
    height: 70px;
    font-size: 16px;
  }
}
</style>
