-- |Contains tests for "Server.Lobby" module.
module Server.LobbyTest where

import Test.QuickCheck
import Test.QuickCheck.Monadic
import Control.Concurrent (readMVar, newMVar)
import Haste.App (SessionID)

import qualified Server.Lobby
import ArbitraryLobbyTypes ()
import LobbyTypes
import Hastings.Database.Common (migrateDatabase)
import Hastings.Database.Player (clearOnlinePlayers)

-- To run in ghci
-- :l test/Server/LobbyTest.hs src/Hastings/ServerUtils.hs src/Hastings/Utils.hs src/LobbyTypes.hs test/ArbitraryLobbyTypes.hs src/Server/Lobby.hs src/Server/Game.hs src/Server/Chat.hs src/Hastings/Database/Player.hs

preProp :: IO ()
preProp = do
  migrateDatabase
  clearOnlinePlayers

-- |Property for connect that makes sure that after running connect a ClientEntry with
-- sessionID and name is found in the list.
prop_connect :: Name -> [ClientEntry] -> Property
prop_connect playerName list = monadicIO $ do
  run preProp
  sessionIDWord64 <- pick $ elements [184468..282345]
  mVar <- run $ newMVar list
  run $ Server.Lobby.connect mVar playerName sessionIDWord64
  conList <- run $ readMVar mVar
  assert $ any (\c -> sessionIDWord64 == sessionID c && name c == playerName) conList

-- |Property for disconnect that checks that after disconnecting, the cliententry
-- is removed from all games and the list of clients.
prop_disconnect :: Int  -- ^The index of player to remove
                -> [ClientEntry] -> [LobbyGame] -> Property
prop_disconnect i clientList gameList = monadicIO $ do
  pre $ not $ null clientList
  let i' = abs $ mod i $ length clientList
  let client = clientList !! i'
  let sid = sessionID client
  run $ preProp

  clientMVar <- run $ newMVar clientList
  gameMVar <- run $ newMVar gameList

  run $ Server.Lobby.disconnect clientMVar gameMVar sid

  newClientList <- run $ readMVar clientMVar
  newGameList <- run $ readMVar gameMVar

  assert $
    (all (client /=) newClientList) &&
    (all (\(_,gd) -> all (client /=) $ players gd) newGameList)

-- |Property for getting the names of connected players.
-- Might seem trivial right now.
prop_getConnectedPlayerNames :: [ClientEntry] -> Property
prop_getConnectedPlayerNames list = monadicIO $ do
  run $ preProp
  clientMVar <- run $ newMVar list
  nameList <- run $ Server.Lobby.getConnectedPlayerNames clientMVar
  assert $ nameList == map name list

-- |Property that makes sure that after calling changeNickName
-- there is no player with the old name and sessionID left.
prop_changeNickName :: Int  -- ^Index of the player to change nick name
                    -> [ClientEntry] -> [LobbyGame] -> Property
prop_changeNickName i clientList gameList = monadicIO $ do
  pre $ not $ null clientList
  let i' = abs $ mod i $ length clientList
  let client = clientList !! i'
  let sid = sessionID client
  let playerName = name client
  run preProp

  clientMVar <- run $ newMVar clientList
  gameMVar <- run $ newMVar gameList

  run $ Server.Lobby.changeNickName clientMVar gameMVar sid "new name"

  newClientList <- run $ readMVar clientMVar
  newGameList <- run $ readMVar gameMVar

  assert $
    all (changeNickNameAssert playerName "new name" sid) newClientList &&
    all (\(_,gd) ->
      all (changeNickNameAssert playerName "new name" sid) $ players gd)
    newGameList

-- |Helper function to check the lists of ClientEntry
-- that the player with 'SessionID' has changed name.
changeNickNameAssert :: Name -> Name -> SessionID -> ClientEntry -> Bool
changeNickNameAssert oldName newName sid c | sid == sessionID c =
  oldName /= playerName && newName == playerName
                                           | otherwise = True
  where
    playerName = name c
