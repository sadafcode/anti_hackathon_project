FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY tsconfig.json ./
COPY backend/ ./backend/

RUN npx tsc --skipLibCheck

# Compiled code (dist/tools/) resolves ../../data → /app/data/
# backend/data/ is at /app/backend/data/ — copy it to where dist expects it
RUN cp -r /app/backend/data /app/data

EXPOSE 8080

ENV PORT=8080

CMD ["node", "dist/app.js"]
