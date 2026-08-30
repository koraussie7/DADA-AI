const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(express.static(path.join(__dirname)));
app.use(express.json());
app.get('/', (req, res) => res.sendFile(path.join(__dirname, 'index.html')));

// ─── 사용자 DB ──────────────────────────────────────────────────────
const DB_PATH = path.join(__dirname, 'users.json');

function loadDB() {
  try {
    const data = fs.readFileSync(DB_PATH, 'utf8');
    return JSON.parse(data);
  } catch { return { users: {}, tokens: {} }; }
}

function saveDB(db) {
  fs.writeFileSync(DB_PATH, JSON.stringify(db, null, 2));
}

let db = loadDB();

// ─── 비밀번호 해싱 ──────────────────────────────────────────────────
const SALT_LEN = 16;
const KEY_LEN = 64;
const SCRYPT_PARAMS = { N: 16384, r: 8, p: 1 };

function hashPassword(password) {
  return new Promise((resolve, reject) => {
    const salt = crypto.randomBytes(SALT_LEN);
    crypto.scrypt(password, salt, KEY_LEN, SCRYPT_PARAMS, (err, key) => {
      if (err) reject(err);
      else resolve(salt.toString('hex') + ':' + key.toString('hex'));
    });
  });
}

function verifyPassword(password, stored) {
  return new Promise((resolve, reject) => {
    const parts = stored.split(':');
    const salt = Buffer.from(parts[0], 'hex');
    const key = Buffer.from(parts[1], 'hex');
    crypto.scrypt(password, salt, KEY_LEN, SCRYPT_PARAMS, (err, derived) => {
      if (err) reject(err);
      else resolve(crypto.timingSafeEqual(key, derived));
    });
  });
}

function generateToken() {
  return crypto.randomBytes(32).toString('hex');
}

// ─── 인증 미들웨어 ──────────────────────────────────────────────────
function authMiddleware(req, res, next) {
  const token = req.headers.authorization || req.query.token;
  db = loadDB();
  const username = db.tokens[token];
  if (!username) return res.status(401).json({ error: '로그인이 필요합니다.' });
  req.username = username;
  req.user = db.users[username];
  next();
}

// ─── API 엔드포인트 ─────────────────────────────────────────────────
app.post('/api/register', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: '아이디와 비밀번호를 입력하세요.' });
  const cleanUser = username.trim().toLowerCase();
  if (cleanUser.length < 2 || cleanUser.length > 20) return res.status(400).json({ error: '아이디는 2~20자 입니다.' });
  if (password.length < 4) return res.status(400).json({ error: '비밀번호는 4자 이상입니다.' });

  db = loadDB();
  if (db.users[cleanUser]) return res.status(409).json({ error: '이미 존재하는 아이디입니다.' });

  const hashed = await hashPassword(password);
  db.users[cleanUser] = {
    password: hashed,
    money: 10000000,
    createdAt: new Date().toISOString()
  };

  const token = generateToken();
  db.tokens[token] = cleanUser;
  saveDB(db);

  res.json({ token, user: { username: cleanUser, money: 10000000 } });
});

app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: '아이디와 비밀번호를 입력하세요.' });
  const cleanUser = username.trim().toLowerCase();

  db = loadDB();
  const user = db.users[cleanUser];
  if (!user) return res.status(401).json({ error: '아이디 또는 비밀번호가 일치하지 않습니다.' });

  const match = await verifyPassword(password, user.password);
  if (!match) return res.status(401).json({ error: '아이디 또는 비밀번호가 일치하지 않습니다.' });

  const token = generateToken();
  db.tokens[token] = cleanUser;
  saveDB(db);

  res.json({ token, user: { username: cleanUser, money: user.money } });
});

app.post('/api/logout', (req, res) => {
  const token = req.body.token || req.headers.authorization || req.query.token;
  if (token) {
    db = loadDB();
    delete db.tokens[token];
    saveDB(db);
  }
  res.json({ ok: true });
});

app.get('/api/me', authMiddleware, (req, res) => {
  res.json({ user: { username: req.username, money: req.user.money } });
});

// ─── Socket.io 인증 ─────────────────────────────────────────────────
io.use((socket, next) => {
  const token = socket.handshake.auth?.token || socket.handshake.query?.token;
  if (!token) {
    socket.username = 'guest_' + Math.random().toString(36).substring(2, 7);
    socket.userMoney = 10000000;
    socket.isGuest = true;
    return next();
  }
  db = loadDB();
  const username = db.tokens[token];
  if (!username) return next(new Error('인증이 필요합니다.'));
  socket.username = username;
  socket.userMoney = db.users[username]?.money || 10000000;
  next();
});

const rooms = {};

// ─── 화투 카드 정의 ───────────────────────────────────────────────
const DECK = [
  // 1월 소나무
  { id: 0,  month: 1,  type: 'gwang',    sub: null,    name: '송학광',    double: false },
  { id: 1,  month: 1,  type: 'ribbon',   sub: 'hong',  name: '솔홍단',    double: false },
  { id: 2,  month: 1,  type: 'pi',       sub: null,    name: '솔피',      double: false },
  { id: 3,  month: 1,  type: 'pi',       sub: null,    name: '솔피',      double: false },
  // 2월 매화
  { id: 4,  month: 2,  type: 'yeolkkut', sub: null,    name: '매조',      double: false },
  { id: 5,  month: 2,  type: 'ribbon',   sub: 'hong',  name: '매홍단',    double: false },
  { id: 6,  month: 2,  type: 'pi',       sub: null,    name: '매피',      double: false },
  { id: 7,  month: 2,  type: 'pi',       sub: null,    name: '매피',      double: false },
  // 3월 벚꽃
  { id: 8,  month: 3,  type: 'gwang',    sub: null,    name: '벚꽃광',    double: false },
  { id: 9,  month: 3,  type: 'ribbon',   sub: 'hong',  name: '벚홍단',    double: false },
  { id: 10, month: 3,  type: 'pi',       sub: null,    name: '벚피',      double: false },
  { id: 11, month: 3,  type: 'pi',       sub: null,    name: '벚피',      double: false },
  // 4월 등나무
  { id: 12, month: 4,  type: 'yeolkkut', sub: null,    name: '등자리',    double: false },
  { id: 13, month: 4,  type: 'ribbon',   sub: 'plain', name: '등평단',    double: false },
  { id: 14, month: 4,  type: 'pi',       sub: null,    name: '등피',      double: false },
  { id: 15, month: 4,  type: 'pi',       sub: null,    name: '등피',      double: false },
  // 5월 난초
  { id: 16, month: 5,  type: 'yeolkkut', sub: null,    name: '난이',      double: false },
  { id: 17, month: 5,  type: 'ribbon',   sub: 'plain', name: '난평단',    double: false },
  { id: 18, month: 5,  type: 'pi',       sub: null,    name: '난피',      double: false },
  { id: 19, month: 5,  type: 'pi',       sub: null,    name: '난피',      double: false },
  // 6월 모란
  { id: 20, month: 6,  type: 'yeolkkut', sub: null,    name: '목단나비',  double: false },
  { id: 21, month: 6,  type: 'ribbon',   sub: 'cheong',name: '목청단',    double: false },
  { id: 22, month: 6,  type: 'pi',       sub: null,    name: '목피',      double: false },
  { id: 23, month: 6,  type: 'pi',       sub: null,    name: '목피',      double: false },
  // 7월 홍싸리
  { id: 24, month: 7,  type: 'yeolkkut', sub: null,    name: '홍이',      double: false },
  { id: 25, month: 7,  type: 'ribbon',   sub: 'plain', name: '홍평단',    double: false },
  { id: 26, month: 7,  type: 'pi',       sub: null,    name: '홍피',      double: false },
  { id: 27, month: 7,  type: 'pi',       sub: null,    name: '홍피',      double: false },
  // 8월 공산
  { id: 28, month: 8,  type: 'gwang',    sub: null,    name: '공산광',    double: false },
  { id: 29, month: 8,  type: 'yeolkkut', sub: null,    name: '공산이',    double: false },
  { id: 30, month: 8,  type: 'pi',       sub: null,    name: '공산피',    double: false },
  { id: 31, month: 8,  type: 'pi',       sub: null,    name: '공산피',    double: false },
  // 9월 국화
  { id: 32, month: 9,  type: 'yeolkkut', sub: null,    name: '국진',      double: false },
  { id: 33, month: 9,  type: 'ribbon',   sub: 'cheong',name: '국청단',    double: false },
  { id: 34, month: 9,  type: 'pi',       sub: null,    name: '국피',      double: false },
  { id: 35, month: 9,  type: 'pi',       sub: null,    name: '국피',      double: false },
  // 10월 단풍
  { id: 36, month: 10, type: 'yeolkkut', sub: null,    name: '단풍사슴',  double: false },
  { id: 37, month: 10, type: 'ribbon',   sub: 'cheong',name: '단청단',    double: false },
  { id: 38, month: 10, type: 'pi',       sub: null,    name: '단피',      double: false },
  { id: 39, month: 10, type: 'pi',       sub: null,    name: '단피',      double: false },
  // 11월 오동
  { id: 40, month: 11, type: 'gwang',    sub: null,    name: '오동광',    double: false },
  { id: 41, month: 11, type: 'yeolkkut', sub: null,    name: '오동이',    double: false },
  { id: 42, month: 11, type: 'pi',       sub: null,    name: '오동피',    double: false },
  { id: 43, month: 11, type: 'pi',       sub: null,    name: '오동피',    double: false },
  // 12월 비
  { id: 44, month: 12, type: 'gwang',    sub: null,    name: '비광',      double: false },
  { id: 45, month: 12, type: 'yeolkkut', sub: null,    name: '비열끗',    double: false },
  { id: 46, month: 12, type: 'pi',       sub: null,    name: '비쌍피',    double: true  },
  { id: 47, month: 12, type: 'pi',       sub: null,    name: '비피',      double: false },
];

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function dealCards(playerIds) {
  const n = playerIds.length;
  const handSize = n === 2 ? 10 : n === 3 ? 7 : 5;
  const fieldSize = n === 2 ? 8 : n === 3 ? 6 : 4;

  const deck = shuffle(DECK.map(c => ({ ...c })));
  const hands = {};
  playerIds.forEach(pid => {
    hands[pid] = deck.splice(0, handSize);
  });
  const field = deck.splice(0, fieldSize);
  return { hands, field, deck };
}

function calcScore(captured, room, pid) {
  const gwang    = captured.filter(c => c.type === 'gwang');
  const yeol     = captured.filter(c => c.type === 'yeolkkut');
  const ribbons  = captured.filter(c => c.type === 'ribbon');
  const piAll    = captured.filter(c => c.type === 'pi');
  const piCount  = piAll.reduce((s, c) => s + (c.double ? 2 : 1), 0);

  let score = 0;
  const breakdown = { gwang: 0, yeol: 0, ribbon: 0, pi: 0 };

  // 광
  const gc = gwang.length;
  const hasRain = gwang.some(c => c.month === 12);
  if (gc === 3) { breakdown.gwang = hasRain ? 2 : 3; }
  else if (gc === 4) { breakdown.gwang = 4; }
  else if (gc >= 5) { breakdown.gwang = 15; }
  score += breakdown.gwang;

  // 열끗
  if (yeol.length >= 5) {
    breakdown.yeol = yeol.length - 4;
    score += breakdown.yeol;
  }

  // 단 (띠)
  const hong  = ribbons.filter(c => c.sub === 'hong').length;
  const cheong = ribbons.filter(c => c.sub === 'cheong').length;
  const plain = ribbons.filter(c => c.sub === 'plain').length;
  if (hong >= 3)   breakdown.ribbon += 3;
  if (cheong >= 3) breakdown.ribbon += 3;
  if (plain >= 3)  breakdown.ribbon += 3;
  if (ribbons.length >= 5) breakdown.ribbon += ribbons.length - 4;
  score += breakdown.ribbon;

  // 피
  if (piCount >= 10) {
    breakdown.pi = piCount - 9;
    score += breakdown.pi;
  }

  // 쪽 점수 추가
  if (room && room.game && room.game.jjotCount && room.game.jjotCount[pid]) {
    score += room.game.jjotCount[pid];
  }
  return { score, breakdown, counts: { gwang: gc, yeol: yeol.length, ribbon: ribbons.length, pi: piCount } };
}

// ─── 쪽 / 흔들기 체크 ────────────────────────────────────────────────
function checkJjotShake(hand, field) {
  const monthCount = {};
  hand.forEach(c => { monthCount[c.month] = (monthCount[c.month] || 0) + 1; });
  const result = { jjot: [], shake: [] };
  Object.entries(monthCount).forEach(([monthStr, count]) => {
    const month = parseInt(monthStr);
    if (count >= 2) {
      const fieldMatch = field.filter(c => c.month === month);
      if (fieldMatch.length >= 1) {
        result.jjot.push({ month, handCards: hand.filter(c => c.month === month).slice(0, 2), fieldCards: fieldMatch });
      } else {
        result.shake.push({ month, handCards: hand.filter(c => c.month === month).slice(0, 2) });
      }
    }
  });
  return result;
}

// ─── 상태 전송 ─────────────────────────────────────────────────────
function broadcast(room) {
  const game = room.game;
  if (!game) return;

  const nameMap = {};
  const playerScores = {};
  room.players.forEach(p => { playerScores[p.id] = p.money || 0; });
  room.players.forEach(p => { nameMap[p.id] = p.name; });

  game.playerIds.forEach(pid => {
    const sock = io.sockets.sockets.get(pid);
    if (!sock) return;

    const scores = {};
    game.playerIds.forEach(p => { scores[p] = calcScore(game.captured[p], room, p); });

    sock.emit('game_state', {
      myId:            pid,
      myHand:          game.hands[pid],
      field:           game.field,
      captured:        game.captured,
      handSizes:       Object.fromEntries(game.playerIds.map(p => [p, game.hands[p].length])),
      currentPlayerId: game.playerIds[game.turnIdx],
      isMyTurn:        pid === game.playerIds[game.turnIdx],
      playerIds:       game.playerIds,
      nameMap,
      scores,
      goCount:         game.goCount,
      deckSize:        game.deck.length,
      phase:           game.phase,
      lastPlay:        game.lastPlay,
      playerScores,
    });
  });
}

function nextTurn(room) {
  const game = room.game;
  game.turnIdx = (game.turnIdx + 1) % game.playerIds.length;
  game.phase = 'play';
  game.lastPlay = null;
  game.pendingHandCard = null;
}

function endGame(room, stopperId = null) {
  const game = room.game;
  room.state = "finished";

  const nameMap = {};
  room.players.forEach(p => { nameMap[p.id] = p.name; });

  const results = {};
  game.playerIds.forEach(pid => {
    const { score, breakdown, counts } = calcScore(game.captured[pid], room, pid);
    const mult = Math.pow(2, game.goCount[pid]);
    const matgoMult = room.mode === 'matgo' ? (score >= 14 ? 3 : score >= 7 ? 2 : 1) : 1;
    results[pid] = { score, total: score * mult * matgoMult, mult, matgoMult, breakdown, counts, goCount: game.goCount[pid] };
  });

  const winner = stopperId || game.playerIds.reduce((best, pid) =>
    results[pid].score > results[best].score ? pid : best, game.playerIds[0]);

  // ── 머니 정산 ────────────────────────────────────────────────────
  const playerScores = {};
  const deltas = {};
  room.players.forEach(p => { playerScores[p.id] = p.money || 0; });

  game.playerIds.forEach(pid => {
    if (pid === winner) return;
    const mult = results[pid].mult * (results[pid].matgoMult || 1);
    const pay = Math.floor(results[winner].score * 100 * mult);
    const actualPay = Math.min(pay, playerScores[pid]);
    playerScores[pid] -= actualPay;
    playerScores[winner] += actualPay;
    deltas[pid] = -actualPay;
  });
  deltas[winner] = playerScores[winner] - (room.players.find(p => p.id === winner)?.money || 0);

  // 플레이어 money 업데이트
  room.players.forEach(p => {
    if (playerScores[p.id] !== undefined) p.money = playerScores[p.id];
  });

  // ── 계정 머니 반영 (users.json) ──────────────────────────────────
  db = loadDB();
  room.players.forEach(p => {
    const ps = io.sockets.sockets.get(p.id);
    if (ps && ps.username && db.users[ps.username]) {
      const gameProfit = p.money - room.seedMoney;
      db.users[ps.username].money += gameProfit;
    }
  });
  saveDB(db);


  // ── 상금 지급 (prizePool) ──────────────────────────────────────────
  if (room.prizePool > 0) {
    db = loadDB();
    const winnerSocket = io.sockets.sockets.get(winner);
    if (winnerSocket && winnerSocket.username && db.users[winnerSocket.username]) {
      db.users[winnerSocket.username].money += room.prizePool;
      saveDB(db);
    }
  }
  io.to(room.id).emit("game_over", { winner, nameMap, results, playerScores, deltas, mode: room.mode || 'gostop' });

  // 파산 체크
  const bankrupt = room.players.filter(p => p.money <= 0);
  if (bankrupt.length > 0) {
    io.to(room.id).emit("chat", { system: true, msg: "💀 파산! 방이 종료됩니다." });
  }
}

// ─── 캡처 헬퍼 ────────────────────────────────────────────────────
function resolveCapture(card, field, chosenFieldId) {
  const matches = field.filter(c => c.month === card.month);
  let captured = [];
  let newField = [...field];

  if (matches.length === 0) {
    // 필드에 내려놓음
    newField.push(card);
  } else if (matches.length === 1) {
    captured = [card, matches[0]];
    newField = newField.filter(c => c.id !== matches[0].id);
  } else if (matches.length === 2) {
    // 플레이어가 선택한 경우
    if (chosenFieldId != null) {
      const chosen = matches.find(c => c.id === chosenFieldId);
      if (chosen) {
        captured = [card, chosen];
        newField = newField.filter(c => c.id !== chosen.id);
      } else {
        // fallback: 첫 번째 선택
        captured = [card, matches[0]];
        newField = newField.filter(c => c.id !== matches[0].id);
      }
    } else {
      // 선택 필요 → null 반환 신호
      return null;
    }
  } else {
    // 3장 폭탄: 전부 획득
    captured = [card, ...matches];
    newField = newField.filter(c => !matches.map(m => m.id).includes(c.id));
  }

  return { captured, field: newField };
}

// ─── 방 목록 브로드캐스트 ──────────────────────────────────────────
function broadcastRoomList() {
  const list = Object.entries(rooms)
    .filter(([, r]) => r.state === 'waiting')
    .map(([id, r]) => ({
      id,
      playerCount: r.players.length,
      seedMoney: r.seedMoney,
      entryFee: r.entryFee || 0,
      prizePool: r.prizePool || 0,
      mode: r.mode || 'gostop',
      hostName: r.players[0]?.name || '?'
    }));
  io.emit('room_list', { rooms: list });
}

// ─── 소켓 이벤트 ──────────────────────────────────────────────────
io.on('connection', socket => {
  console.log('접속:', socket.id, '유저:', socket.username);


  // ─── 쪽 / 흔들기 이벤트 ────────────────────────────────────────────
  socket.on('check_actions', () => {
    const room = rooms[socket.roomId];
    if (!room || room.state !== 'playing' || !room.game) return;
    const game = room.game;
    const pid = socket.id;
    if (pid !== game.playerIds[game.turnIdx]) return;
    if (game.phase !== 'play') return;
    const possible = checkJjotShake(game.hands[pid], game.field);
    socket.emit('available_actions', { jjot: possible.jjot, shake: possible.shake });
  });

  socket.on('jjot', ({ month }) => {
    const room = rooms[socket.roomId];
    if (!room || room.state !== 'playing' || !room.game) return;
    const game = room.game;
    const pid = socket.id;
    if (pid !== game.playerIds[game.turnIdx]) return;
    if (game.phase !== 'play') return;
    const hand = game.hands[pid];
    const handMatches = hand.filter(c => c.month === month);
    if (handMatches.length < 2) return socket.emit('err', '쪽을 할 수 없습니다.');
    const fieldMatches = game.field.filter(c => c.month === month);
    if (fieldMatches.length < 1) return socket.emit('err', '필드에 같은 월 카드가 없습니다.');
    const rmCards = handMatches.slice(0, 2);
    rmCards.forEach(c => { const idx = hand.findIndex(h => h.id === c.id); if (idx >= 0) hand.splice(idx, 1); });
    const fieldCard = fieldMatches[0];
    game.field = game.field.filter(c => c.id !== fieldCard.id);
    game.captured[pid].push(...rmCards, fieldCard);
    game.jjotCount = game.jjotCount || {};
    game.jjotCount[pid] = (game.jjotCount[pid] || 0) + 3;
    io.to(room.id).emit('chat', { system: true, msg: `🃏 ${socket.playerName}이(가) 쪽! (${month}월 3점 획득!)` });
    game.lastPlay = { jjot: true, month };
    game.phase = 'deck';
    game.pendingHandCard = null;
    processDeckCard(room, pid);
  });

  socket.on('shake', ({ month }) => {
    const room = rooms[socket.roomId];
    if (!room || room.state !== 'playing' || !room.game) return;
    const game = room.game;
    const pid = socket.id;
    if (pid !== game.playerIds[game.turnIdx]) return;
    if (game.phase !== 'play') return;
    const hand = game.hands[pid];
    const handMatches = hand.filter(c => c.month === month);
    if (handMatches.length < 2) return socket.emit('err', '흔들기를 할 수 없습니다.');
    game.shaken = game.shaken || {};
    if (!game.shaken[pid]) game.shaken[pid] = [];
    game.shaken[pid].push(month);
    const otherPlayers = room.players.filter(p => p.id !== pid);
    otherPlayers.forEach(p => {
      const sock = io.sockets.sockets.get(p.id);
      if (sock) sock.emit('opponent_shake', { name: socket.playerName, month });
    });
    io.to(room.id).emit('chat', { system: true, msg: `👋 ${socket.playerName}이(가) 흔들었다! (${month}월)` });
    socket.emit('chat', { system: true, msg: `👋 ${month}월을 흔들었습니다!` });
    nextTurn(room);
    broadcast(room);
  });

  socket.on("create_room", ({ name, seedMoney, entryFee, mode }) => {
  const seed = Math.min(Math.max(parseInt(seedMoney) || 1000, 100), 999999);
  const fee = Math.min(Math.max(parseInt(entryFee) || 0, 0), 1000000);
    const roomId = Math.floor(1000 + Math.random() * 9000).toString();
    rooms[roomId] = {
      id: roomId,
      players: [{ id: socket.id, name, money: seed }],
      state: "waiting",
      game: null,
      seedMoney: seed,
      entryFee: fee,
      prizePool: 0,
      mode: mode || 'gostop',
    };
    socket.join(roomId);
    socket.roomId = roomId;
    socket.playerName = name;
    socket.emit("room_ready", { roomId, players: rooms[roomId].players, isHost: true, seedMoney: seed, entryFee: fee, prizePool: 0, mode: mode || 'gostop' });
    broadcastRoomList();
  });

  socket.on('join_room', ({ roomId, name }) => {
    const room = rooms[roomId];    if (!room) return socket.emit('err', '방을 찾을 수 없습니다.');
  // 입장료 확인
  if (room.entryFee > 0) {
    db = loadDB();
    const joiner = db.users[socket.username];
    if (!joiner) return socket.emit('err', '로그인이 필요합니다.');
    if (joiner.money < room.entryFee) return socket.emit('err', '잔액이 부족합니다. (필요: ' + room.entryFee.toLocaleString() + '원)');
    joiner.money -= room.entryFee;
    room.prizePool += room.entryFee;
    saveDB(db);
  }
    if (room.state !== 'waiting') return socket.emit('err', '이미 진행 중인 게임입니다.');
    if (room.players.length >= 4) return socket.emit('err', '방이 가득 찼습니다.');

    room.players.push({ id: socket.id, name, money: room.seedMoney });
    socket.join(roomId);
    socket.roomId = roomId;
    socket.playerName = name;

    io.to(roomId).emit('player_joined', { players: room.players });
    socket.emit('room_ready', { roomId, players: room.players, isHost: false, seedMoney: room.seedMoney, entryFee: room.entryFee, prizePool: room.prizePool, mode: room.mode });
    broadcastRoomList();
  });

  socket.on('start_game', () => {
    const room = rooms[socket.roomId];
    if (!room) return;
    if (room.players[0].id !== socket.id) return socket.emit('err', '방장만 시작 가능합니다.');
    if (room.players.length < 2)          return socket.emit('err', '2명 이상 필요합니다.');

    const pids = room.players.map(p => p.id);
    const { hands, field, deck } = dealCards(pids);

    room.state = 'playing';
    room.game = {
      hands, field, deck,
      captured:        Object.fromEntries(pids.map(p => [p, []])),
      goCount:         Object.fromEntries(pids.map(p => [p, 0])),
      playerIds:       pids,
      turnIdx:         0,
      phase:           'play',
      pendingHandCard: null,
      mode: room.mode || 'gostop',
      entryFee: room.entryFee || 0,
      prizePool: room.prizePool || 0,
      lastPlay:        null,
    };

    broadcast(room);
    io.to(room.id).emit('game_started');
  });

  // 손패 카드 내려놓기
  socket.on('play_card', ({ cardId, fieldChoiceId }) => {
    const room = rooms[socket.roomId];
    if (!room || room.state !== 'playing') return;
    const game = room.game;
    const pid = game.playerIds[game.turnIdx];
    if (socket.id !== pid) return;
    if (game.phase !== 'play' && game.phase !== 'choose_field') return;
    if (game.phase === 'choose_field' && cardId !== game.pendingHandCard?.id) {
      return socket.emit('err', '선택 대기 중인 카드가 아닙니다.');
    }

    const hand = game.hands[pid];
    const cardIdx = hand.findIndex(c => c.id === cardId);
    if (cardIdx === -1) return;

    const card = hand[cardIdx];
    hand.splice(cardIdx, 1);

    const result = resolveCapture(card, game.field, fieldChoiceId ?? null);

    if (result === null) {
      // 2장 매칭 → 선택 대기
      hand.splice(cardIdx, 0, card); // 되돌리기
      game.phase = 'choose_field';
      game.pendingHandCard = card;
      socket.emit('choose_field_card', {
        card,
        choices: game.field.filter(c => c.month === card.month).map(c => c.id),
      });
      return;
    }

    game.captured[pid].push(...result.captured);
    game.field = result.field;
    game.lastPlay = { handCard: card, handCaptured: result.captured.map(c => c.id) };
    game.phase = 'deck';
    game.pendingHandCard = null;

    // 덱 카드 공개
    processDeckCard(room, pid);
  });

  // 덱 카드 필드 선택 (2장 매칭 시)
  socket.on('choose_deck_field', ({ fieldChoiceId }) => {
    const room = rooms[socket.roomId];
    if (!room || room.state !== 'playing') return;
    const game = room.game;
    const pid = game.playerIds[game.turnIdx];
    if (socket.id !== pid) return;
    if (game.phase !== 'choose_deck_field') return;

    const deckCard = game.pendingDeckCard;
    const result = resolveCapture(deckCard, game.field, fieldChoiceId);
    if (!result) {
      return socket.emit('err', '잘못된 선택입니다.');
    }

    game.captured[pid].push(...result.captured);
    game.field = result.field;
    if (game.lastPlay) {
      game.lastPlay.deckCard = deckCard;
      game.lastPlay.deckCaptured = result.captured.map(c => c.id);
    }
    game.pendingDeckCard = null;

    afterDeckCard(room, pid);
  });

  // 고/스톱 결정
  socket.on('go_stop', ({ decision }) => {
    const room = rooms[socket.roomId];
    if (!room || room.state !== 'playing') return;
    const game = room.game;
    const pid = game.playerIds[game.turnIdx];
    if (socket.id !== pid) return;
    if (game.phase !== 'go_stop') return;

    if (decision === 'stop') {
      endGame(room, pid);
    } else {
      game.goCount[pid]++;
      io.to(room.id).emit('chat', { system: true, msg: `🔥 ${socket.playerName}이(가) 고! (${game.goCount[pid]}고)` });
      nextTurn(room);
      broadcast(room);
    }
  });

  socket.on('chat', ({ msg }) => {
    if (!socket.roomId) return;
    io.to(socket.roomId).emit('chat', { name: socket.playerName, msg });
  });

  socket.on('disconnect', () => {
    const room = rooms[socket.roomId];
    // 입장료 환불 (게임 시작 전 나간 경우)
    if (room && room.state === 'waiting') {
      const leavingPlayer = room.players.find(p => p.id === socket.id);
      if (leavingPlayer && room.entryFee > 0) {
        db = loadDB();
        if (db.users[socket.username]) {
          db.users[socket.username].money += room.entryFee;
          room.prizePool -= room.entryFee;
          saveDB(db);
        }
      }
    }
    if (!room) return;
    room.players = room.players.filter(p => p.id !== socket.id);
    if (room.players.length === 0) {
      delete rooms[socket.roomId];
    } else {
      io.to(socket.roomId).emit('player_left', { name: socket.playerName, players: room.players });
      if (room.state === 'playing') endGame(room);
    }
    broadcastRoomList();
  });
});

// ─── 덱 카드 처리 ─────────────────────────────────────────────────
function processDeckCard(room, pid) {
  const game = room.game;

  if (game.deck.length === 0) {
    afterDeckCard(room, pid);
    return;
  }

  const deckCard = game.deck.shift();
  const matches = game.field.filter(c => c.month === deckCard.month);

  if (matches.length === 2) {
    // 선택 대기
    game.phase = 'choose_deck_field';
    game.pendingDeckCard = deckCard;
    if (game.lastPlay) game.lastPlay.deckCard = deckCard;
    broadcast(room);
    const sock = io.sockets.sockets.get(pid);
    if (sock) sock.emit('choose_deck_field_card', {
      card: deckCard,
      choices: matches.map(c => c.id),
    });
    return;
  }

  const result = resolveCapture(deckCard, game.field, null);
  if (result) {
    game.captured[pid].push(...result.captured);
    game.field = result.field;
    if (game.lastPlay) {
      game.lastPlay.deckCard = deckCard;
      game.lastPlay.deckCaptured = result.captured.map(c => c.id);
    }
  }

  afterDeckCard(room, pid);
}

function afterDeckCard(room, pid) {
  const game = room.game;
  const allEmpty = game.playerIds.every(p => game.hands[p].length === 0);
  const { score } = calcScore(game.captured[pid], room, pid);

  // 맞고 모드: 3점 이상이면 자동 종료, 아니면 계속 진행
  if (room.mode === 'matgo') {
    if (score >= 3) {
      endGame(room, pid);
    } else if (allEmpty || game.deck.length === 0) {
      endGame(room);
    } else {
      nextTurn(room);
      broadcast(room);
    }
    return;
  }
  if (score >= 3 && !allEmpty) {
    game.phase = 'go_stop';
    broadcast(room);
    const nameMap = {};
    room.players.forEach(p => { nameMap[p.id] = p.name; });
    io.to(room.id).emit('go_stop_prompt', { pid, name: nameMap[pid], score });
  } else if (allEmpty || game.deck.length === 0) {
    endGame(room);
  } else {
    nextTurn(room);
    broadcast(room);
  }
}

// ─── 서버 시작 ─────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`\n🎴 고스톱 서버 실행 중 → http://localhost:${PORT}\n`);
});
