/* ============================================================
 * input.js — 키보드 / 마우스 입력
 * 화면(스케일된 캔버스) 좌표를 내부 저해상도 좌표로 변환해 제공.
 * ============================================================ */
(function () {
  'use strict';

  const Input = {
    keys: {},          // 현재 눌린 키
    pressed: {},       // 이번 프레임에 새로 눌린 키 (한 번만 true)
    mouse: { x: 0, y: 0, down: false, clicked: false },
    canvas: null,
    scaleX: 1, scaleY: 1,

    init(canvas, internalW, internalH) {
      this.canvas = canvas;
      this.internalW = internalW;
      this.internalH = internalH;

      window.addEventListener('keydown', (e) => {
        const k = e.key.length === 1 ? e.key.toLowerCase() : e.key;
        if (!this.keys[k]) this.pressed[k] = true;
        this.keys[k] = true;
        // 게임 단축키가 스크롤/기본동작을 가로채지 않게
        if ([' ', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key)) e.preventDefault();
      });
      window.addEventListener('keyup', (e) => {
        const k = e.key.length === 1 ? e.key.toLowerCase() : e.key;
        this.keys[k] = false;
      });

      const updateMouse = (e) => {
        const r = canvas.getBoundingClientRect();
        this.mouse.x = ((e.clientX - r.left) / r.width) * internalW;
        this.mouse.y = ((e.clientY - r.top) / r.height) * internalH;
      };
      canvas.addEventListener('mousemove', updateMouse);
      canvas.addEventListener('mousedown', (e) => { updateMouse(e); this.mouse.down = true; this.mouse.clicked = true; });
      window.addEventListener('mouseup', () => { this.mouse.down = false; });
      canvas.addEventListener('contextmenu', (e) => e.preventDefault());
    },

    // 키가 "방금" 눌렸는지 (엣지 트리거)
    justPressed(k) { return !!this.pressed[k]; },
    isDown(k) { return !!this.keys[k]; },

    // 매 프레임 끝에서 호출: 1회성 상태 초기화
    endFrame() {
      this.pressed = {};
      this.mouse.clicked = false;
    },
  };

  window.Input = Input;
})();
