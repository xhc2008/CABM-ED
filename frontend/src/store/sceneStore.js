import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useSceneStore = defineStore('scene', () => {
  const scenes = ref([])
  const currentSceneId = ref(null)
  const currentWeatherId = ref(null)
  const currentTimeId = ref(null)
  const autoMode = ref(false)

  // 当前选中的时间段配置
  const currentTime = computed(() => {
    if (!currentSceneId.value || !currentWeatherId.value || !currentTimeId.value) return null
    
    const scene = scenes.value.find(s => s.id === currentSceneId.value)
    if (!scene) return null
    
    const weather = scene.weathers.find(w => w.id === currentWeatherId.value)
    if (!weather) return null
    
    return weather.times.find(t => t.id === currentTimeId.value)
  })

  // 获取当前时间段（白天/傍晚/夜晚）
  const getCurrentTimeOfDay = () => {
    const hour = new Date().getHours()
    // 凌晨(0-6)算作傍晚, 白天(6-17), 傍晚(17-19), 夜晚(19-24)
    if (hour >= 4 && hour < 7) return 'dusk'  // 凌晨算傍晚
    if (hour >= 8 && hour < 17) return 'day'
    if (hour >= 17 && hour < 19) return 'dusk'
    return 'night'
  }

  // 加载场景数据
  const loadScenes = async () => {
    try {
      // 开发环境使用代理，生产环境使用动态地址
      const apiUrl = import.meta.env.DEV ? '' : (() => {
        const backendPort = import.meta.env.VITE_BACKEND_PORT || '8000'
        const protocol = window.location.protocol
        const hostname = window.location.hostname
        return `${protocol}//${hostname}:${backendPort}`
      })()
      
      const response = await fetch(`${apiUrl}/api/scenes`)
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      const data = await response.json()
      console.log('加载的场景数据:', data)
      console.log('使用的 API 地址:', apiUrl)
      scenes.value = data.scenes
      
      // 默认选择第一个场景的第一个天气的第一个时间段
      if (scenes.value.length > 0 && scenes.value[0].weathers.length > 0) {
        currentSceneId.value = scenes.value[0].id
        currentWeatherId.value = scenes.value[0].weathers[0].id
        
        const firstWeather = scenes.value[0].weathers[0]
        if (firstWeather.times && firstWeather.times.length > 0) {
          // 如果是自动模式，根据当前时间选择
          if (autoMode.value) {
            const timeOfDay = getCurrentTimeOfDay()
            const matchedTime = firstWeather.times.find(t => t.id === timeOfDay)
            currentTimeId.value = matchedTime ? matchedTime.id : firstWeather.times[0].id
          } else {
            currentTimeId.value = firstWeather.times[0].id
          }
        }
        console.log('当前配置:', currentTime.value)
      }
    } catch (error) {
      console.error('加载场景数据失败:', error)
      // 使用默认数据
      loadDefaultScenes()
    }
  }

  // 加载默认场景（开发时使用）
  const loadDefaultScenes = () => {
    scenes.value = [
      {
        id: 'scene1',
        name: '场景 1',
        weathers: [
          {
            id: 'sunny',
            name: '晴天',
            times: [
              {
                id: 'day',
                name: '白天',
                image: 'day.png',
                atmosphere: {
                  brightness: 1.0,
                  contrast: 1.0,
                  saturation: 1.0
                }
              }
            ]
          }
        ]
      }
    ]
    
    if (scenes.value.length > 0 && scenes.value[0].weathers.length > 0) {
      currentSceneId.value = scenes.value[0].id
      currentWeatherId.value = scenes.value[0].weathers[0].id
      if (scenes.value[0].weathers[0].times.length > 0) {
        currentTimeId.value = scenes.value[0].weathers[0].times[0].id
      }
    }
  }

  // 选择场景
  const selectScene = (sceneId) => {
    currentSceneId.value = sceneId
    // 保持当前天气和时间，如果新场景没有则选择第一个
    const scene = scenes.value.find(s => s.id === sceneId)
    if (scene && scene.weathers.length > 0) {
      const weather = scene.weathers.find(w => w.id === currentWeatherId.value)
      if (!weather) {
        currentWeatherId.value = scene.weathers[0].id
        if (scene.weathers[0].times.length > 0) {
          currentTimeId.value = scene.weathers[0].times[0].id
        }
      }
    }
  }

  // 选择天气
  const selectWeather = (weatherId) => {
    currentWeatherId.value = weatherId
    // 保持当前时间段，如果新天气没有则选择第一个
    const scene = scenes.value.find(s => s.id === currentSceneId.value)
    if (scene) {
      const weather = scene.weathers.find(w => w.id === weatherId)
      if (weather && weather.times.length > 0) {
        const time = weather.times.find(t => t.id === currentTimeId.value)
        if (!time) {
          currentTimeId.value = weather.times[0].id
        }
      }
    }
  }

  // 选择时间段
  const selectTime = (timeId) => {
    currentTimeId.value = timeId
  }

  // 切换自动模式
  const toggleAutoMode = () => {
    autoMode.value = !autoMode.value
    if (autoMode.value) {
      // 开启自动模式时，根据当前时间选择时间段
      const timeOfDay = getCurrentTimeOfDay()
      const scene = scenes.value.find(s => s.id === currentSceneId.value)
      if (scene) {
        const weather = scene.weathers.find(w => w.id === currentWeatherId.value)
        if (weather) {
          const matchedTime = weather.times.find(t => t.id === timeOfDay)
          if (matchedTime) {
            currentTimeId.value = matchedTime.id
          }
        }
      }
    }
  }

  return {
    scenes,
    currentTime,
    currentSceneId,
    currentWeatherId,
    currentTimeId,
    autoMode,
    loadScenes,
    selectScene,
    selectWeather,
    selectTime,
    toggleAutoMode
  }
})
