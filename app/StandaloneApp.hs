{-# LANGUAGE CPP #-}
-- |Main module of the Lobby
module Main
    where
import Haste.App
import Haste.App.Standalone
import Haste.App.Concurrent
import qualified Control.Concurrent as CC
import Views.Lobby

import LobbyAPI
import GameAPI

#ifdef __HASTE__
import LobbyClient (clientMain)
#define disconnect(x) (\_ -> return ())
#define migrateDatabase (return ())
#define clearOnlinePlayers (return ())
#else
import Server (disconnect)
import Hastings.Database.Common (migrateDatabase)
import Hastings.Database.Player (clearOnlinePlayers)
#define clientMain (\_ _ -> return ())
#endif

-- |Main method and entry point for the program
main :: IO ()
main = runStandaloneApp $ do
  playersList <- liftServerIO $ CC.newMVar []
  chatList <- liftServerIO $ CC.newMVar []

  let serverState = (playersList, chatList)
  liftServerIO $ migrateDatabase
  liftServerIO $ clearOnlinePlayers

  onSessionEnd $ disconnect(serverState)
  api <- newLobbyAPI (playersList, chatList)
  runClient $ clientMain api newGameAPI
