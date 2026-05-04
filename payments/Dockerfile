FROM node:18-alpine

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --only=production

#Copy the remaining source files
COPY src/ ./src
COPY dist/ ./dist

#Expose the correct port
EXPOSE 3000

ENV PORT=3000
ENV APP_VERSION=1.0.0

CMD ["node", "dist/server.js"]