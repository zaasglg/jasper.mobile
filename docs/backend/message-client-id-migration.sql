ALTER TABLE "messages" ADD COLUMN "clientId" TEXT;
CREATE UNIQUE INDEX "messages_userId_clientId_key" ON "messages"("userId", "clientId");
