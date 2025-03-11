# Use a lightweight Node.js image
FROM node:18

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# If node_modules exists, skip npm install
COPY node_modules ./node_modules

# Copy the rest of your application files
COPY . .

EXPOSE 3000

# Run the application
CMD ["npm", "start"]
