import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import WebSocket, { WebSocketServer } from 'ws';

const PORT = Number(process.env.PORT ?? 8080);
const DEFAULT_ROOM_ID = 'main-room';

const initialBetTargets = [
  { id: 'target-1', name: 'Red Phoenix', winRate: 0.42, odds: 2.1 },
  { id: 'target-2', name: 'Blue Nova', winRate: 0.28, odds: 3.8 },
  { id: 'target-3', name: 'Golden Tide', winRate: 0.18, odds: 5.2 },
  { id: 'target-4', name: 'Silver Fang', winRate: 0.12, odds: 7.4 },
];

const rooms = new Map([
  [
    DEFAULT_ROOM_ID,
    {
      id: DEFAULT_ROOM_ID,
      name: 'Bet Hub Room',
      members: [
        { id: 'member-1', name: 'Saki', coins: 720 },
        { id: 'member-2', name: 'Taro', coins: 430 },
        { id: 'member-3', name: 'Mina', coins: 910 },
      ],
      betTargets: initialBetTargets,
      bets: [
        { memberId: 'member-1', targetId: 'target-1', amount: 120 },
        { memberId: 'member-1', targetId: 'target-3', amount: 80 },
        { memberId: 'member-2', targetId: 'target-2', amount: 150 },
        { memberId: 'member-3', targetId: 'target-4', amount: 300 },
      ],
    },
  ],
]);

const connections = new Map();

const server = createServer();
const wss = new WebSocketServer({ server });

wss.on('connection', (socket) => {
  const connectionId = randomUUID();
  connections.set(socket, { connectionId, memberId: null, roomId: null });

  socket.on('message', (rawMessage) => {
    try {
      const message = JSON.parse(rawMessage.toString());
      handleMessage(socket, message);
    } catch (error) {
      send(socket, 'error', { message: `Invalid message: ${error.message}` });
    }
  });

  socket.on('close', () => {
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
    case 'join_room':
      handleJoinRoom(socket, payload);
      break;
    case 'submit_bet':
      handleSubmitBet(socket, payload);
      break;
    default:
      send(socket, 'error', { message: `Unsupported message type: ${type}` });
  }
}

function handleJoinRoom(socket, payload) {
  const roomId = typeof payload.roomId === 'string' ? payload.roomId : DEFAULT_ROOM_ID;
  const userName = typeof payload.userName === 'string' ? payload.userName.trim() : '';

  if (!userName) {
    send(socket, 'error', { message: 'ユーザー名を入力してください。' });
    return;
  }

  const room = rooms.get(roomId);
  if (!room) {
    send(socket, 'error', { message: '指定された部屋が見つかりません。' });
    return;
  }

  const duplicate = room.members.some(
    (member) => member.name.toLowerCase() === userName.toLowerCase(),
  );
  if (duplicate) {
    send(socket, 'error', { message: 'その名前はすでに使用されています。' });
    return;
  }

  removeMember(socket);

  const connection = connections.get(socket);
  const memberId = connection?.connectionId ?? randomUUID();
  const member = { id: memberId, name: userName, coins: 500 };
  room.members = [...room.members, member];

  connections.set(socket, { connectionId: memberId, memberId, roomId });
  send(socket, 'join_room_success', { roomId, memberId });
  broadcastRoomSnapshot(roomId);
}

function handleSubmitBet(socket, payload) {
  const connection = connections.get(socket);
  if (!connection?.memberId || !connection.roomId) {
    send(socket, 'error', { message: '先に入室してください。' });
    return;
  }

  const room = rooms.get(connection.roomId);
  if (!room) {
    send(socket, 'error', { message: '部屋情報が見つかりません。' });
    return;
  }

  const targetId = typeof payload.targetId === 'string' ? payload.targetId : '';
  const amount = Number(payload.amount);
  if (!targetId || !Number.isInteger(amount) || amount < 0) {
    send(socket, 'error', { message: 'ベット内容が不正です。' });
    return;
  }

  const index = room.bets.findIndex(
    (bet) => bet.memberId === connection.memberId && bet.targetId === targetId,
  );

  if (index === -1) {
    room.bets = [...room.bets, { memberId: connection.memberId, targetId, amount }];
  } else {
    const nextBets = [...room.bets];
    nextBets[index] = { ...nextBets[index], amount };
    room.bets = nextBets;
  }

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

  const nextMembers = room.members.filter((member) => member.id !== connection.memberId);
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

    send(client, 'room_snapshot', {
      roomId: room.id,
      roomName: room.name,
      members: room.members,
      betTargets: room.betTargets,
      bets: room.bets,
    });
  }
}

function send(socket, type, payload) {
  socket.send(JSON.stringify({ type, payload }));
}
