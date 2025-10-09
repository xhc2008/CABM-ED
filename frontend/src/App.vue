<template>
  <div class="app-container">
    <!-- 背景图片/视频层 -->
    <div 
      class="background-layer"
      :style="backgroundStyle"
    >
      <!-- 视频背景 -->
      <video 
        v-if="currentTime?.image && isVideoFile(currentTime.image)"
        :src="`${API_URL}${currentTime.image}`"
        class="background-media"
        autoplay
        loop
        muted
        playsinline
        @error="handleMediaError"
        @loadeddata="handleMediaLoad"
      />
      <!-- 图片背景 -->
      <img 
        v-else-if="currentTime?.image" 
        :src="`${API_URL}${currentTime.image}`" 
        :alt="currentTime.name"
        class="background-media"
        @error="handleMediaError"
        @load="handleMediaLoad"
      />
      <div v-else class="no-image">
        <p>暂无背景</p>
      </div>
    </div>

    <!-- 侧边栏 -->
    <Sidebar 
      :scenes="scenes"
      :currentSceneId="currentSceneId"
      :currentWeatherId="currentWeatherId"
      :currentTimeId="currentTimeId"
      :autoMode="autoMode"
      :isOpen="sidebarOpen"
      @toggle="sidebarOpen = !sidebarOpen"
      @selectScene="handleSceneSelect"
      @selectWeather="handleWeatherSelect"
      @selectTime="handleTimeSelect"
      @toggleAuto="handleToggleAuto"
    />

    <!-- 音频播放器 -->
    <AudioPlayer 
      :audioPath="currentTime?.audio"
      :apiUrl="API_URL"
    />
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import Sidebar from './components/Sidebar.vue'
import AudioPlayer from './components/AudioPlayer.vue'
import { useSceneStore } from './store/sceneStore'

const sceneStore = useSceneStore()
const sidebarOpen = ref(false)

// 从环境变量获取 API 地址
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000'

// 调试：打印 API 地址
console.log('API_URL:', API_URL)
console.log('所有环境变量:', import.meta.env)

// 从 store 获取数据
const scenes = computed(() => sceneStore.scenes)
const currentTime = computed(() => sceneStore.currentTime)
const currentSceneId = computed(() => sceneStore.currentSceneId)
const currentWeatherId = computed(() => sceneStore.currentWeatherId)
const currentTimeId = computed(() => sceneStore.currentTimeId)
const autoMode = computed(() => sceneStore.autoMode)

// 计算背景样式（应用氛围效果）
const backgroundStyle = computed(() => {
  if (!currentTime.value?.atmosphere) return {}
  
  const { brightness, contrast, saturation } = currentTime.value.atmosphere
  return {
    filter: `brightness(${brightness}) contrast(${contrast}) saturate(${saturation})`
  }
})

const handleSceneSelect = (sceneId) => {
  sceneStore.selectScene(sceneId)
}

const handleWeatherSelect = (weatherId) => {
  sceneStore.selectWeather(weatherId)
}

const handleTimeSelect = (timeId) => {
  sceneStore.selectTime(timeId)
}

const handleToggleAuto = () => {
  sceneStore.toggleAutoMode()
}

// 判断是否为视频文件
const isVideoFile = (filename) => {
  if (!filename) return false
  const ext = filename.toLowerCase().split('.').pop()
  return ['mp4', 'webm', 'ogg'].includes(ext)
}

const handleMediaError = (e) => {
  const mediaType = e.target.tagName.toLowerCase()
  console.error(`❌ ${mediaType === 'video' ? '视频' : '图片'}加载失败:`, e.target.src)
  console.error('   当前时间段数据:', currentTime.value)
  console.error('   API_URL:', API_URL)
}

const handleMediaLoad = (e) => {
  const mediaType = e.target.tagName.toLowerCase()
  console.log(`✅ ${mediaType === 'video' ? '视频' : '图片'}加载成功:`, e.target.src)
}

// 初始化加载场景数据
sceneStore.loadScenes()
</script>

<style scoped>
.app-container {
  position: relative;
  width: 100%;
  height: 100%;
}

.background-layer {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  transition: filter 0.5s ease;
}

.background-media {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.no-image {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  font-size: 24px;
}
</style>
