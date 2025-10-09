<template>
  <div class="audio-player">
    <audio 
      ref="audioRef" 
      :src="audioSrc" 
      loop
      @error="handleError"
      @canplay="handleCanPlay"
    />
    
    <button 
      class="audio-toggle" 
      @click="toggleAudio"
      :title="isPlaying ? '静音' : '播放音效'"
    >
      <svg v-if="isPlaying" viewBox="0 0 24 24" width="24" height="24">
        <path fill="currentColor" d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/>
      </svg>
      <svg v-else viewBox="0 0 24 24" width="24" height="24">
        <path fill="currentColor" d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/>
      </svg>
    </button>
  </div>
</template>

<script setup>
import { ref, watch, computed } from 'vue'

const props = defineProps({
  audioPath: {
    type: String,
    default: null
  },
  apiUrl: {
    type: String,
    required: true
  }
})

const audioRef = ref(null)
const isPlaying = ref(false)
const isReady = ref(false)

const audioSrc = computed(() => {
  if (!props.audioPath) return null
  return `${props.apiUrl}${props.audioPath}`
})

// 监听音频路径变化
watch(audioSrc, async (newSrc) => {
  if (!audioRef.value) return
  
  isReady.value = false
  
  if (newSrc) {
    // 停止当前播放
    audioRef.value.pause()
    audioRef.value.currentTime = 0
    
    // 等待新音频加载
    try {
      await audioRef.value.load()
      if (isPlaying.value) {
        await audioRef.value.play()
      }
    } catch (error) {
      console.error('音频加载失败:', error)
    }
  } else {
    audioRef.value.pause()
  }
})

const toggleAudio = async () => {
  if (!audioRef.value || !audioSrc.value) return
  
  try {
    if (isPlaying.value) {
      audioRef.value.pause()
      isPlaying.value = false
    } else {
      await audioRef.value.play()
      isPlaying.value = true
    }
  } catch (error) {
    console.error('音频播放失败:', error)
  }
}

const handleError = (e) => {
  console.error('音频加载错误:', audioSrc.value, e)
  isPlaying.value = false
  isReady.value = false
}

const handleCanPlay = () => {
  isReady.value = true
  console.log('音频已准备就绪:', audioSrc.value)
}
</script>

<style scoped>
.audio-player {
  position: fixed;
  bottom: 30px;
  right: 30px;
  z-index: 1000;
}

.audio-toggle {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.9);
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  transition: all 0.3s ease;
  color: #333;
}

.audio-toggle:hover {
  background: rgba(255, 255, 255, 1);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.2);
  transform: scale(1.05);
}

.audio-toggle:active {
  transform: scale(0.95);
}

.audio-toggle svg {
  width: 28px;
  height: 28px;
}
</style>
