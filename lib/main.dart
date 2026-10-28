<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Football Arena Pro</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: radial-gradient(circle at center, #0f2e1d, #081b12 60%, #040f0b);
      font-family: Arial, sans-serif;
      color: white;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      overflow: hidden;
    }

    #game-wrap {
      position: relative;
      width: min(96vw, 1000px);
      aspect-ratio: 5/3;
      border-radius: 18px;
      box-shadow: 0 0 30px rgba(0,0,0,0.4);
      overflow: hidden;
      border: 4px solid rgba(255,255,255,0.18);
      background: #1f6e3a;
    }

    canvas {
      width: 100%;
      height: 100%;
      display: block;
      background: linear-gradient(#1d7f42, #176c3b);
    }

    .hud {
      position: absolute;
      top: 18px;
      left: 50%;
      transform: translateX(-50%);
      display: flex;
      gap: 18px;
      align-items: center;
      background: rgba(0,0,0,0.28);
      border: 1px solid rgba(255,255,255,0.2);
      border-radius: 12px;
      padding: 10px 16px;
      backdrop-filter: blur(4px);
    }

    .hud .score {
      font-size: clamp(18px, 2vw, 32px);
      font-weight: bold;
      letter-spacing: 2px;
      text-shadow: 0 2px 10px rgba(0,0,0,0.4);
    }

    .hud .timer {
      font-size: clamp(16px, 1.5vw, 26px);
      font-weight: bold;
      color: #e6f0ff;
    }

    .controls {
      position: absolute;
      bottom: 18px;
      left: 50%;
      transform: translateX(-50%);
      font-size: 12px;
      letter-spacing: 1px;
      opacity: 0.85;
      background: rgba(0,0,0,0.2);
      padding: 8px 12px;
      border-radius: 10px;
      border: 1px solid rgba(255,255,255,0.12);
    }
  </style>
</head>
<body>
  <div id="game-wrap">
    <canvas id="game" width="1000" height="600"></canvas>
    <div class="hud">
      <div class="score" id="score">0 - 0</div>
      <div class="timer" id="timer">90</div>
    </div>
    <div class="controls">التحكم: W A S D / الأسهم • التسديد: Space</div>
  </div>

  <script>
    const canvas = document.getElementById("game");
    const ctx = canvas.getContext("2d");
    const scoreEl = document.getElementById("score");
    const timerEl = document.getElementById("timer");

    const keys = {};
    const field = {
      width: canvas.width,
      height: canvas.height,
      goalTop: 180,
      goalBottom: 420,
      goalDepth: 90,
      centerX: canvas.width / 2
    };

    let lastTime = 0;
    let matchTime = 90;
    let gameOver = false;

    const state = {
      scoreLeft: 0,
      scoreRight: 0,
      ball: null,
      players: [],
      best: false
    };

    function clamp(value, min, max) {
      return Math.min(Math.max(value, min), max);
    }

    function distance(a, b) {
      return Math.hypot(a.x - b.x, a.y - b.y);
    }

    function createPlayer(x, y, color, side, controlled = false) {
      return {
        x, y,
        radius: 18,
        color,
        speed: 3.7,
        vx: 0,
        vy: 0,
        side,
        controlled,
        kickCooldown: 0,
        hasBall: false
      };
    }

    function resetBall() {
      state.ball = {
        x: field.centerX,
        y: field.height / 2,
        radius: 11,
        vx: 0,
        vy: 0,
        owner: null
      };
    }

    function createPlayers() {
      state.players = [
        createPlayer(120, 230, "#4ec5ff", "left", true),
        createPlayer(120, 370, "#4ec5ff", "left", false),
        createPlayer(880, 230, "#ff6b6b", "right", false),
        createPlayer(880, 370, "#ff6b6b", "right", false)
      ];
      resetBall();
    }

    function setBallOwner(player) {
      state.ball.owner = player;
      player.hasBall = true;
      for (const p of state.players) {
        if (p !== player) p.hasBall = false;
      }
    }

    function releaseBall(player) {
      if (state.ball.owner === player) {
        state.ball.owner = null;
        player.hasBall = false;
      }
    }

    function updateScoreboard() {
      scoreEl.textContent = `${state.scoreLeft} - ${state.scoreRight}`;
      timerEl.textContent = String(Math.max(0, Math.ceil(matchTime)));
    }

    function setControls() {
      window.addEventListener("keydown", (e) => {
        const key = e.key.toLowerCase();
        keys[key] = true;

        if (key === " " || e.code === "Space") {
          e.preventDefault();
          tryKick();
        }
      });

      window.addEventListener("keyup", (e) => {
        keys[e.key.toLowerCase()] = false;
      });
    }

    function tryKick() {
      const player = state.players.find(p => p.controlled);
      if (!player) return;
      if (state.ball.owner === player) {
        const dx = (keys["d"] || keys["arrowright"]) ? 1 : (keys["a"] || keys["arrowleft"]) ? -1 : 0;
        const dy = (keys["s"] || keys["arrowdown"]) ? 1 : (keys["w"] || keys["arrowup"]) ? -1 : 0;
        let dirX = 1;
        let dirY = 0;

        if (player.side === "left") dirX = 1;
        else dirX = -1;

        if (dx !== 0 || dy !== 0) {
          dirX = dx || dirX;
          dirY = dy || 0;
        }

        const length = Math.hypot(dirX, dirY) || 1;
        const power = 10;

        state.ball.vx = (dirX / length) * power;
        state.ball.vy = (dirY / length) * power;
        state.ball.owner = null;
        player.hasBall = false;
      }
    }

    function movePlayer(player, moveX, moveY) {
      if (gameOver) return;

      const distanceNorm = Math.hypot(moveX, moveY) || 1;
      const speed = player.speed;

      player.x += (moveX / distanceNorm) * speed;
      player.y += (moveY / distanceNorm) * speed;

      player.x = clamp(player.x, 25, field.width - 25);
      player.y = clamp(player.y, 25, field.height - 25);

      if (state.ball.owner === player) {
        state.ball.x = player.x + 22 * (player.side === "left" ? 1 : -1);
        state.ball.y = player.y;
      }
    }

    function updateControlledPlayer() {
      const player = state.players.find(p => p.controlled);
      if (!player) return;

      let moveX = 0;
      let moveY = 0;

      if (keys["w"] || keys["arrowup"]) moveY -= 1;
      if (keys["s"] || keys["arrowdown"]) moveY += 1;
      if (keys["a"] || keys["arrowleft"]) moveX -= 1;
      if (keys["d"] || keys["arrowright"]) moveX += 1;

      if (moveX !== 0 || moveY !== 0) {
        movePlayer(player, moveX, moveY);
      }

      if (state.ball.owner === player) {
        const ahead = player.side === "left" ? 1 : -1;
        state.ball.x = player.x + ahead * 22;
        state.ball.y = player.y;
      }
    }

    function updateAI() {
      const aiPlayers = state.players.filter(p => !p.controlled);
      for (const player of aiPlayers) {
        const ball = state.ball;
        const dirX = ball.x - player.x;
        const dirY = ball.y - player.y;
        const dist = Math.hypot(dirX, dirY) || 1;

        if (distance(player, ball) < player.radius + ball.radius + 16) {
          setBallOwner(player);
        }

        if (state.ball.owner === player) {
          const moveDir = {
            x: Math.sign(ball.x - player.x),
            y: Math.sign(ball.y - player.y)
          };

          const kickPower = 11;
          const targetX = player.side === "left" ? field.width - 120 : 120;
          const targetY = field.height / 2;

          const shotDirX = targetX - player.x;
          const shotDirY = targetY - player.y;
          const shotLength = Math.hypot(shotDirX, shotDirY) || 1;

          if (Math.abs(player.x - targetX) < 70 && Math.abs(player.y - targetY) < 70) {
            state.ball.vx = (shotDirX / shotDirLength) * kickPower;
            state.ball.vy = (shotDirY / shotDirLength) * kickPower;
            state.ball.owner = null;
            player.hasBall = false;
          } else {
            player.x += Math.sign(shotDirX) * 2.2;
            player.y += Math.sign(shotDirY) * 2.2;
          }
        } else {
          const targetX = player.side === "left" ? 220 : 780;
          const targetY = player.y < ball.y ? ball.y - 30 : ball.y + 30;
          const dx = targetX - player.x;
          const dy = targetY - player.y;
          const d = Math.hypot(dx, dy) || 1;

          if (Math.abs(dx) > 5 || Math.abs(dy) > 5) {
            player.x += (dx / d) * 1.7;
            player.y += (dy / d) * 1.7;
          }
        }
      }
    }

    function handleBallCollisions() {
      const ball = state.ball;

      for (const player of state.players) {
        const dx = ball.x - player.x;
        const dy = ball.y - player.y;
        const dist = Math.hypot(dx, dy) || 1;

        const minDist = ball.radius + player.radius + 2;
        if (dist < minDist) {
          const nx = dx / dist;
          const ny = dy / dist;
          const overlap = minDist - dist;

          ball.x += nx * overlap;
          ball.y += ny * overlap;

          if (ball.owner !== player && player.side === "left") {
            setBallOwner(player);
          }
          if (ball.owner !== player && player.side === "right") {
            setBallOwner(player);
          }

          if (ball.owner === player) {
            const power = 1.6;
            ball.vx = nx * power;
            ball.vy = ny * power;
          }
        }
      }

      if (!ball.owner) {
        ball.x += ball.vx;
        ball.y += ball.vy;

        ball.vx *= 0.992;
        ball.vy *= 0.992;

        if (Math.abs(ball.vx) < 0.03) ball.vx = 0;
        if (Math.abs(ball.vy) < 0.03) ball.vy = 0;

        if (ball.x < 0 || ball.x > field.width) {
          ball.vx *= -0.7;
          ball.x = clamp(ball.x, 12, field.width - 12);
        }

        if (ball.y < 0 || ball.y > field.height) {
          ball.vy *= -0.7;
          ball.y = clamp(ball.y, 12, field.height - 12);
        }
      }
    }

    function checkGoals() {
      const ball = state.ball;

      const inGoalY = ball.y > field.goalTop && ball.y < field.goalBottom;
      const leftGoal = ball.x <= 0 && inGoalY;
      const rightGoal = ball.x >= field.width && inGoalY;

      if (leftGoal) {
        state.scoreRight += 1;
        resetBall();
        updateScoreboard();
      }

      if (rightGoal) {
        state.scoreLeft += 1;
        resetBall();
        updateScoreboard();
      }
    }

    function updateTimer(delta) {
      if (gameOver) return;
      matchTime -= delta * 0.001;
      if (matchTime <= 0) {
        matchTime = 0;
        gameOver = true;
        alert("انتهت المباراة!\nالنتيجة النهائية: " + state.scoreLeft + " - " + state.scoreRight);
      }
      updateScoreboard();
    }

    function drawField() {
      ctx.clearRect(0, 0, field.width, field.height);
      ctx.fillStyle = "#1a803d";
      ctx.fillRect(0, 0, field.width, field.height);

      ctx.strokeStyle = "rgba(255,255,255,0.8)";
      ctx.lineWidth = 3;
      ctx.strokeRect(20, 20, field.width - 40, field.height - 40);

      // خط الوسط
      ctx.beginPath();
      ctx.moveTo(field.centerX, 20);
      ctx.lineTo(field.centerX, field.height - 20);
      ctx.stroke();

      // الدائرة الوسطية
      ctx.beginPath();
      ctx.arc(field.centerX, field.height / 2, 80, 0, Math.PI * 2);
      ctx.stroke();

      // المرمى الأيسر
      ctx.strokeRect(20, field.goalTop, 90, field.goalBottom - field.goalTop);
      // المرمى الأيمن
      ctx.strokeRect(field.width - 110, field.goalTop, 90, field.goalBottom - field.goalTop);

      // نقاط الركنية
      ctx.beginPath();
      ctx.arc(20, 20, 8, 0, Math.PI * 2); ctx.fillStyle = "white"; ctx.fill();
      ctx.beginPath();
      ctx.arc(field.width - 20, 20, 8, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath();
      ctx.arc(20, field.height - 20, 8, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath();
      ctx.arc(field.width - 20, field.height - 20, 8, 0, Math.PI * 2); ctx.fill();
    }

    function drawPlayers() {
      for (const p of state.players) {
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        ctx.fillStyle = p.color;
        ctx.fill();

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius * 0.5, 0, Math.PI * 2);
        ctx.fillStyle = "rgba(255,255,255,0.3)";
        ctx.fill();

        if (p.controlled) {
          ctx.beginPath();
          ctx.arc(p.x, p.y, p.radius + 6, 0, Math.PI * 2);
          ctx.strokeStyle = "rgba(255,255,255,0.9)";
          ctx.lineWidth = 2;
          ctx.stroke();
        }
      }
    }

    function drawBall() {
      const b = state.ball;
      ctx.beginPath();
      ctx.arc(b.x, b.y, b.radius, 0, Math.PI * 2);
      ctx.fillStyle = "#f5f5f5";
      ctx.fill();

      ctx.beginPath();
      ctx.arc(b.x, b.y, b.radius * 0.5, 0, Math.PI * 2);
      ctx.fillStyle = "#d8d8d8";
      ctx.fill();
    }

    function update(dt) {
      if (gameOver) return;

      updateTimer(dt);
      updateControlledPlayer();
      updateAI();

      handleBallCollisions();
      checkGoals();

      for (const p of state.players) {
        if (p.kickCooldown > 0) p.kickCooldown -= dt;
      }
    }

    function render() {
      drawField();
      drawPlayers();
      drawBall();
    }

    function loop(timestamp) {
      const dt = timestamp - lastTime;
      lastTime = timestamp;

      update(dt);
      render();
      requestAnimationFrame(loop);
    }

    createPlayers();
    setControls();
    updateScoreboard();
    requestAnimationFrame(loop);
  </script>
</body>
</html>