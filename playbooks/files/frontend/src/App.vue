<template>
  <main>
    <h1>Licznik: {{ counter }}</h1>

    <!-- CELOWO PODATNE -->
    <!-- To renderuje parametr x jako HTML -->
    <div style="display: none" v-html="xssPayload"></div>
  </main>
</template>

<script setup>
import { ref, onMounted } from "vue"

const counter = ref("0")
const xssPayload = ref("")

async function loadCounter() {
  const response = await fetch("/api/counter", {
    credentials: "include"
  })

  const data = await response.json()
  counter.value = data.counter
}

onMounted(async () => {
  const params = new URLSearchParams(window.location.search)

  // np. /?x=<img src=x onerror=...>
  xssPayload.value = params.get("x") || ""

  await loadCounter()
})
</script>