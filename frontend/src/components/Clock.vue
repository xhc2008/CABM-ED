<template>
  <div class="clock">
    <div class="clock-face">
      <div 
        class="hand hour-hand" 
        :style="{ transform: `rotate(${hourDeg}deg)` }"
      ></div>
      <div 
        class="hand minute-hand" 
        :style="{ transform: `rotate(${minuteDeg}deg)` }"
      ></div>
      <div 
        class="hand second-hand" 
        :style="{ transform: `rotate(${secondDeg}deg)` }"
      ></div>
      <div class="center-dot"></div>
    </div>
    <div class="digital-time">{{ digitalTime }}</div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const hourDeg = ref(0)
const minuteDeg = ref(0)
const secondDeg = ref(0)
const digitalTime = ref('')

let timer = null

const updateTime = () => {
  const now = new Date()
  const hours = now.getHours()
  const minutes = now.getMinutes()
  const seconds = now.getSeconds()
  
  secondDeg.value = seconds * 6
  minuteDeg.value = minutes * 6 + seconds * 0.1
  hourDeg.value = (hours % 12) * 30 + minutes * 0.5
  
  digitalTime.value = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
}

onMounted(() => {
  updateTime()
  timer = setInterval(updateTime, 1000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<style scoped>
.clock {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 15px;
}

.clock-face {
  position: relative;
  width: 150px;
  height: 150px;
  border: 3px solid #333;
  border-radius: 50%;
  background: white;
}

.hand {
  position: absolute;
  bottom: 50%;
  left: 50%;
  transform-origin: bottom center;
  background: #333;
  border-radius: 3px;
}

.hour-hand {
  width: 6px;
  height: 40px;
  margin-left: -3px;
}

.minute-hand {
  width: 4px;
  height: 55px;
  margin-left: -2px;
}

.second-hand {
  width: 2px;
  height: 60px;
  margin-left: -1px;
  background: #e74c3c;
}

.center-dot {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 12px;
  height: 12px;
  background: #333;
  border-radius: 50%;
  transform: translate(-50%, -50%);
}

.digital-time {
  font-size: 24px;
  font-weight: bold;
  color: #333;
  font-family: 'Courier New', monospace;
}

@media (max-width: 768px) {
  .clock-face {
    width: 120px;
    height: 120px;
  }
  
  .hour-hand {
    height: 32px;
  }
  
  .minute-hand {
    height: 44px;
  }
  
  .second-hand {
    height: 48px;
  }
  
  .digital-time {
    font-size: 20px;
  }
}
</style>
