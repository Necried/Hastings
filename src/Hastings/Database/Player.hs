module Hastings.Database.Player
   where

import Hastings.Database.Common
import Hastings.Database.Fields

import Database.Esqueleto
import Data.Word (Word64)
import Data.Maybe (listToMaybe)


-- |Save a player to the database.
savePlayer :: String -- ^The name of the player to save.
           -> IO (Key Player)
savePlayer name = runDB $ insert $ Player name

-- |Retrieve a player from the database by their username.
retrievePlayerbyUsername :: String -- ^The username of the player to retrieve.
                         -> IO (Maybe (Entity Player))
retrievePlayerbyUsername name = runDB $ getBy $ UniqueUsername name

-- |Save an an online player to the database.
saveOnlinePlayer :: String -- ^The name of the player to save.
                 -> Word64 -- ^The sessionID of the player to save.
                 -> IO (Key OnlinePlayer)
saveOnlinePlayer name sessionID = do
  player <- retrievePlayerbyUsername name
  case player of
    Just entity -> saveOnlinePlayer' (entityKey entity) sessionID
    _           -> do
      key <- savePlayer name
      saveOnlinePlayer' key sessionID

    where
      saveOnlinePlayer' key sessionID = runDB $ insert $ OnlinePlayer key sessionID


-- |Retrieve an online player from the database.
retrieveOnlinePlayer :: Word64 -- ^The sessionID of the player to retrieve.
                     -> IO (Maybe (Entity Player))
retrieveOnlinePlayer sessionID = runDB $ do
  playerList <- select $
       from $ \(b, p) -> do
         where_ (b ^. OnlinePlayerPlayer ==. p ^. PlayerId)
         return p
  return $ listToMaybe playerList

