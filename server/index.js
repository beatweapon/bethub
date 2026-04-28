import { createServer } from "node:http";
import { randomUUID } from "node:crypto";
import WebSocket, { WebSocketServer } from "ws";

const PORT = Number(process.env.PORT ?? 8080);
const DEFAULT_ROOM_ID = "main-room";
const DEFAULT_NEW_TARGET_ODDS = 2.5;
const DEFAULT_NEW_TARGET_WIN_RATE = 0.5;

// オッズ計算のパラメータ
const ODDS_CALCULATION_PARAMS = {
  alpha: 0.5, // 人気の影響度
  beta: 0.5, // 実力の影響度
  k: 2, // 順位計算の指数
};

const initialBetTargets = [
  { id: "target-1", name: "Red Phoenix", winRate: 0.42, odds: 2.1, ranks: [] },
  { id: "target-2", name: "Blue Nova", winRate: 0.28, odds: 3.8, ranks: [] },
  { id: "target-3", name: "Golden Tide", winRate: 0.18, odds: 5.2, ranks: [] },
  { id: "target-4", name: "Silver Fang", winRate: 0.12, odds: 7.4, ranks: [] },
];

const rooms = new Map([
  [
    DEFAULT_ROOM_ID,
    {
      id: DEFAULT_ROOM_ID,
      name: "Bet Hub Room",
      members: [
        { id: "member-1", name: "Saki", coins: 720 },
        { id: "member-2", name: "Taro", coins: 430 },
        { id: "member-3", name: "Mina", coins: 910 },
      ],
      betTargets: initialBetTargets,
      bets: [
        { memberId: "member-1", targetId: "target-1", amount: 120 },
        { memberId: "member-1", targetId: "target-3", amount: 80 },
        { memberId: "member-2", targetId: "target-2", amount: 150 },
        { memberId: "member-3", targetId: "target-4", amount: 300 },
      ],
      raceStatus: "RaceStatus.betting",
      results: [],
    },
  ],
]);

const connections = new Map();

const server = createServer();
const wss = new WebSocketServer({ server });

wss.on("connection", (socket) => {
  const connectionId = randomUUID();
  connections.set(socket, { connectionId, memberId: null, roomId: null });

  socket.on("message", (rawMessage) => {
    try {
      const message = JSON.parse(rawMessage.toString());
      handleMessage(socket, message);
    } catch (error) {
      send(socket, "error", { message: `Invalid message: ${error.message}` });
    }
  });

  socket.on("close", () => {
    removeMember(socket);
    connections.delete(socket);
  });
});

server.listen(PORT, () => {
  console.log(`Bet Hub WebSocket server listening on ws://localhost:${PORT}`);
});

function handleMessage(socket, message) {
  const type = message?.type;
  const payload = message?.payload ?? {};

  switch (type) {
    case "join_room":
      handleJoinRoom(socket, payload);
      break;
    case "submit_bet":
      handleSubmitBet(socket, payload);
      break;
    case "update_race_status":
      handleUpdateRaceStatus(socket, payload);
      break;
    case "add_bet_target":
      handleAddBetTarget(socket, payload);
      break;
    case "submit_race_results":
      handleSubmitRaceResults(socket, payload);
      break;
    default:
      send(socket, "error", { message: `Unsupported message type: ${type}` });
  }
}

function handleJoinRoom(socket, payload) {
  const roomId =
    typeof payload.roomId === "string" ? payload.roomId : DEFAULT_ROOM_ID;
  const userName =
    typeof payload.userName === "string" ? payload.userName.trim() : "";
  const isRoomMaster = userName === "管理者";

  if (!userName) {
    send(socket, "error", { message: "ユーザー名を入力してください。" });
    return;
  }

  const room = rooms.get(roomId);
  if (!room) {
    send(socket, "error", { message: "指定された部屋が見つかりません。" });
    return;
  }

  const duplicate =
    !isRoomMaster &&
    room.members.some(
      (member) => member.name.toLowerCase() === userName.toLowerCase(),
    );
  if (duplicate) {
    send(socket, "error", { message: "その名前はすでに使用されています。" });
    return;
  }

  removeMember(socket);

  const connection = connections.get(socket);
  const connectionId = connection?.connectionId ?? randomUUID();
  const memberId = isRoomMaster ? null : connectionId;

  if (!isRoomMaster) {
    const member = { id: memberId, name: userName, coins: 500 };
    room.members = [...room.members, member];
  }

  connections.set(socket, { connectionId, memberId, roomId });
  send(socket, "join_room_success", { roomId, memberId, isRoomMaster });
  broadcastRoomSnapshot(roomId);
}

function handleSubmitBet(socket, payload) {
  const connection = connections.get(socket);
  if (!connection?.memberId || !connection.roomId) {
    send(socket, "error", { message: "先に入室してください。" });
    return;
  }

  const room = rooms.get(connection.roomId);
  if (!room) {
    send(socket, "error", { message: "部屋情報が見つかりません。" });
    return;
  }

  const targetId = typeof payload.targetId === "string" ? payload.targetId : "";
  const amount = Number(payload.amount);
  if (!targetId || !Number.isInteger(amount) || amount < 0) {
    send(socket, "error", { message: "ベット内容が不正です。" });
    return;
  }

  const index = room.bets.findIndex(
    (bet) => bet.memberId === connection.memberId && bet.targetId === targetId,
  );

  if (index === -1) {
    room.bets = [
      ...room.bets,
      { memberId: connection.memberId, targetId, amount },
    ];
  } else {
    const nextBets = [...room.bets];
    nextBets[index] = { ...nextBets[index], amount };
    room.bets = nextBets;
  }

  broadcastRoomSnapshot(connection.roomId);
}

function handleUpdateRaceStatus(socket, payload) {
  const connection = connections.get(socket);
  if (!connection?.roomId) {
    send(socket, "error", { message: "先に入室してください。" });
    return;
  }

  const room = rooms.get(connection.roomId);
  if (!room) {
    send(socket, "error", { message: "部屋情報が見つかりません。" });
    return;
  }

  const status = typeof payload.status === "string" ? payload.status : "";
  const validStatuses = new Set([
    "RaceStatus.betting",
    "RaceStatus.racing",
    "RaceStatus.finished",
  ]);

  if (!validStatuses.has(status)) {
    send(socket, "error", { message: "レース状態が不正です。" });
    return;
  }

  room.raceStatus = status;
  if (status !== "RaceStatus.finished") {
    room.results = [];
  }

  broadcastRoomSnapshot(connection.roomId);
}

function handleAddBetTarget(socket, payload) {
  const connection = connections.get(socket);
  if (!connection?.roomId) {
    send(socket, "error", { message: "先に入室してください。" });
    return;
  }

  const room = rooms.get(connection.roomId);
  if (!room) {
    send(socket, "error", { message: "部屋情報が見つかりません。" });
    return;
  }

  const targetName =
    typeof payload.targetName === "string" ? payload.targetName.trim() : "";
  if (!targetName) {
    send(socket, "error", { message: "ベット対象名を入力してください。" });
    return;
  }

  const betTarget = {
    id: `target-${randomUUID()}`,
    name: targetName,
    winRate: DEFAULT_NEW_TARGET_WIN_RATE,
    odds: DEFAULT_NEW_TARGET_ODDS,
    ranks: [],
  };

  room.betTargets = [...room.betTargets, betTarget];
  broadcastRoomSnapshot(connection.roomId);
}

function handleSubmitRaceResults(socket, payload) {
  const connection = connections.get(socket);
  if (!connection?.roomId) {
    send(socket, "error", { message: "先に入室してください。" });
    return;
  }

  const room = rooms.get(connection.roomId);
  if (!room) {
    send(socket, "error", { message: "部屋情報が見つかりません。" });
    return;
  }

  const betTargetIds = Array.isArray(payload.betTargetIds)
    ? payload.betTargetIds.filter((id) => typeof id === "string")
    : [];
  const targetIds = room.betTargets.map((target) => target.id);

  if (betTargetIds.length !== targetIds.length) {
    send(socket, "error", { message: "順位データが不正です。" });
    return;
  }

  const uniqueIds = new Set(betTargetIds);
  const hasUnknownTarget = betTargetIds.some((id) => !targetIds.includes(id));
  if (uniqueIds.size !== betTargetIds.length || hasUnknownTarget) {
    send(socket, "error", { message: "順位データが不正です。" });
    return;
  }

  room.raceStatus = "RaceStatus.finished";
  room.results = betTargetIds;

  // 各BetTargetにranksを追加し、オッズと勝率を更新
  room.betTargets = room.betTargets.map((target) => ({
    ...target,
    ranks: [...target.ranks, betTargetIds.indexOf(target.id) + 1],
  }));

  // オッズの再計算と配当の払い戻し
  processPayouts(room);

  broadcastRoomSnapshot(connection.roomId);
}

function removeMember(socket) {
  const connection = connections.get(socket);
  if (!connection?.memberId || !connection.roomId) {
    return;
  }

  const room = rooms.get(connection.roomId);
  if (!room) {
    return;
  }

  const nextMembers = room.members.filter(
    (member) => member.id !== connection.memberId,
  );
  if (nextMembers.length === room.members.length) {
    return;
  }

  room.members = nextMembers;
  room.bets = room.bets.filter((bet) => bet.memberId !== connection.memberId);
  connections.set(socket, {
    connectionId: connection.connectionId,
    memberId: null,
    roomId: null,
  });

  broadcastRoomSnapshot(room.id);
}

function broadcastRoomSnapshot(roomId) {
  const room = rooms.get(roomId);
  if (!room) {
    return;
  }

  for (const client of wss.clients) {
    if (client.readyState !== WebSocket.OPEN) {
      continue;
    }

    const connection = connections.get(client);
    if (connection?.roomId !== roomId) {
      continue;
    }

    send(client, "room_snapshot", {
      roomId: room.id,
      roomName: room.name,
      members: room.members,
      betTargets: room.betTargets,
      bets: room.bets,
      raceStatus: room.raceStatus,
      results: room.results,
    });
  }
}

function send(socket, type, payload) {
  socket.send(JSON.stringify({ type, payload }));
}

// 各BetTargetの実効ランクを計算
function calculateEffectiveRank(ranks) {
  if (ranks.length === 0) return 999;
  const avgRank = ranks.reduce((a, b) => a + b, 0) / ranks.length;
  return Math.max(1, avgRank);
}

// 勝率を計算: p_i = (1 / effectiveRank_i^k) / Σ (1 / effectiveRank_j^k)
function calculateWinRates(betTargets) {
  const { k } = ODDS_CALCULATION_PARAMS;
  const inverseRanks = betTargets.map((target) => {
    const effectiveRank = calculateEffectiveRank(target.ranks);
    return 1 / Math.pow(effectiveRank, k);
  });
  const sumInverseRanks = inverseRanks.reduce((a, b) => a + b, 0);
  return inverseRanks.map((inv) =>
    sumInverseRanks > 0 ? inv / sumInverseRanks : 0,
  );
}

// オッズを計算: odds_i = Σ bet_j / effective_weight_i
// effective_weight_i = (bet_i^α) * (p_i^β)
function calculateOdds(betTargets, bets) {
  const { alpha, beta } = ODDS_CALCULATION_PARAMS;
  const winRates = calculateWinRates(betTargets);

  // 各BetTargetへの賭け合計を計算
  const betsByTarget = new Map();
  bets.forEach((bet) => {
    const current = betsByTarget.get(bet.targetId) || 0;
    betsByTarget.set(bet.targetId, current + bet.amount);
  });

  const totalBets = bets.reduce((sum, bet) => sum + bet.amount, 0) || 1;

  return betTargets.map((target, index) => {
    const bet_i = betsByTarget.get(target.id) || 1;
    const p_i = winRates[index];
    const effectiveWeight =
      Math.pow(bet_i, alpha) * Math.pow(Math.max(0.01, p_i), beta);
    return effectiveWeight > 0 ? totalBets / effectiveWeight : 0;
  });
}

// 配当を処理して払い戻す
function processPayouts(room) {
  const odds = calculateOdds(room.betTargets, room.bets);
  const winnerTargetId = room.results[0]; // 1位の競技対象ID

  // 1位の対象にベットした人に配当を払い戻す
  const winnerBets = room.bets.filter((bet) => bet.targetId === winnerTargetId);
  const winnerTargetIndex = room.betTargets.findIndex(
    (t) => t.id === winnerTargetId,
  );
  const winnerOdds = winnerTargetIndex !== -1 ? odds[winnerTargetIndex] : 1;

  winnerBets.forEach((bet) => {
    const memberIndex = room.members.findIndex((m) => m.id === bet.memberId);
    if (memberIndex !== -1) {
      const payout = Math.floor(bet.amount * Math.max(1, winnerOdds));
      room.members[memberIndex].coins += payout;
    }
  });

  // BetTargetのoddsとwinRateを更新
  const winRates = calculateWinRates(room.betTargets);
  room.betTargets = room.betTargets.map((target, index) => ({
    ...target,
    odds: Math.max(1, odds[index] || DEFAULT_NEW_TARGET_ODDS),
    winRate: winRates[index],
  }));

  // 次のレース準備：betsをリセット
  room.bets = [];
  room.raceStatus = "RaceStatus.betting";
}
