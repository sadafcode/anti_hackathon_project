FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY tsconfig.json ./
COPY backend/ ./backend/

RUN npx tsc --skipLibCheck

EXPOSE 8080

ENV PORT=8080

CMD ["node", "dist/app.js"]
