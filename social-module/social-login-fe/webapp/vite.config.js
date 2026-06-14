import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // 바닐라(vanilla-html)와 동일한 포트 → 공급자 콘솔에 등록된 redirect URI
    // (http://localhost:3005/callback.html) 를 그대로 재사용하기 위함.
    // 같은 포트라 vanilla-html과 동시에 띄울 수는 없고, 하나씩 실행한다.
    port: 3005,
    strictPort: true,
  },
  build: {
    // 멀티 페이지: 콜백은 /callback.html 로 진입 (바닐라와 동일 경로)
    rollupOptions: {
      input: {
        main: 'index.html',
        callback: 'callback.html',
      },
    },
  },
})
