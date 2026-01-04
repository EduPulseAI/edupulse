# Frontend Applications

## Overview

Next.js 15 application with TypeScript providing:
- Student adaptive learning UI
- Instructor real-time dashboard
- WebSocket-based real-time updates

## Project Structure

```
frontend/
├── src/
│   ├── app/
│   │   ├── student/
│   │   │   └── [studentId]/
│   │   │       └── page.tsx
│   │   ├── instructor/
│   │   │   └── dashboard/
│   │   │       └── page.tsx
│   │   └── layout.tsx
│   ├── components/
│   │   ├── student/
│   │   │   ├── QuestionDisplay.tsx
│   │   │   ├── AnswerForm.tsx
│   │   │   └── HintPanel.tsx
│   │   ├── instructor/
│   │   │   ├── EngagementHeatmap.tsx
│   │   │   └── TipsPanel.tsx
│   │   └── shared/
│   │       └── ConnectionStatus.tsx
│   └── lib/
│       ├── websocket.ts
│       ├── api.ts
│       └── types.ts
├── public/
├── package.json
└── README.md
```

## Student UI

**Route:** `/student/[studentId]`

**Features:**
- Question display with multiple choice answers
- Submit answer button
- Real-time hint panel
- Difficulty indicator (1-5 stars)
- Attempt counter
- Loading states

**Key Component:**


## Instructor Dashboard

**Route:** `/instructor/dashboard`

**Features:**
- Real-time engagement heatmap (3x3 grid of students)
- Color-coded tiles (green/yellow/red)
- Tips panel with priority badges
- Student drill-down view

**Key Component:**

```typescript
// src/app/instructor/dashboard/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { useWebSocket } from '@/lib/websocket';
import EngagementHeatmap from '@/components/instructor/EngagementHeatmap';
import TipsPanel from '@/components/instructor/TipsPanel';

export default function InstructorDashboard() {
  const [engagementMap, setEngagementMap] = useState(new Map());
  const [tips, setTips] = useState([]);
  const { message } = useWebSocket('instructor_1', 'instructor');

  useEffect(() => {
    if (message?.type === 'engagement.update') {
      setEngagementMap(prev => new Map(prev).set(
        message.payload.studentId,
        message.payload.score
      ));
    }
    
    if (message?.type === 'instructor.tip') {
      setTips(prev => [message.payload, ...prev].slice(0, 10));
    }
  }, [message]);

  return (
    <div className="grid grid-cols-12 gap-4 p-6">
      <div className="col-span-8">
        <EngagementHeatmap data={engagementMap} />
      </div>
      <div className="col-span-4">
        <TipsPanel tips={tips} />
      </div>
    </div>
  );
}
```

## WebSocket Hook

```typescript
// src/lib/websocket.ts
import { useEffect, useState } from 'react';

interface WebSocketMessage {
  type: string;
  payload: any;
}

export function useWebSocket(userId: string, userType: 'student' | 'instructor') {
  const [message, setMessage] = useState<WebSocketMessage | null>(null);
  const [connected, setConnected] = useState(false);
  const [ws, setWs] = useState<WebSocket | null>(null);

  useEffect(() => {
    const token = getAuthToken(); // From localStorage or session
    const socket = new WebSocket(
      `ws://localhost:8086/ws?token=${token}&userId=${userId}&userType=${userType}`
    );

    socket.onopen = () => {
      console.log('WebSocket connected');
      setConnected(true);
    };

    socket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      setMessage(data);
    };

    socket.onclose = () => {
      console.log('WebSocket disconnected');
      setConnected(false);
      
      // Reconnect after 2 seconds
      setTimeout(() => {
        setWs(null); // Trigger reconnection
      }, 2000);
    };

    socket.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    setWs(socket);

    return () => {
      socket.close();
    };
  }, [userId, userType]);

  return { message, connected, ws };
}
```

## Local Development Setup

```bash
cd frontend

# Install dependencies
npm install

# Set environment variables
cat > .env.local << EOF
NEXT_PUBLIC_API_URL=http://localhost:8081
NEXT_PUBLIC_WS_URL=ws://localhost:8086
EOF

# Run development server
npm run dev

# Open browser
open http://localhost:3000
```

## Demo / Simulation Mode

Add demo mode toggle for rapid testing:

```typescript
// src/lib/config/index.ts
export const DEMO_MODE = process.env.NEXT_PUBLIC_DEMO_MODE === 'true';

export const DEMO_CONFIG = {
  autoSubmitDelay: 2000, // Auto-submit answers after 2s
  skipAnimations: true,
  mockWebSocket: false,
};

// In components:
if (DEMO_MODE) {
  setTimeout(() => {
    handleSubmit(demoAnswers[currentIndex]);
  }, DEMO_CONFIG.autoSubmitDelay);
}
```

**Enable demo mode:**

```bash
NEXT_PUBLIC_DEMO_MODE=true npm run dev
```

## Build for Production

```bash
npm run build
npm run start
```

---
