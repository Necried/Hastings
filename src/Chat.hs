module Chat
    (
    addPlayerToChat,
    createNewChatRoom,
    removePlayerFromChats,
    Chat,
    ConcurrentChatList
    ) where

import Haste.App
import Data.List
import Hastings.Utils
import LobbyTypes
import Data.Maybe
import qualified Control.Concurrent as CC

-- |Adds a player to the main chat room. If it doesn't exists, do nothing.
addPlayerToChat :: SessionID -> Name -> [Chat] -> [Chat]
addPlayerToChat sid = updateLookup (\sids -> nub $ sid : sids)

removePlayerFromChat :: SessionID -> Name -> [Chat] -> [Chat]
removePlayerFromChat sid = updateLookup (delete sid)

removePlayerFromChats :: SessionID -> [Chat] -> [Chat]
removePlayerFromChats sid = map (removeSessionFromChat sid)

createNewChatRoom :: String -> (Name, [SessionID])
createNewChatRoom name = (name, [])

-- | Adds a SessinID to a chat. If SessionID already exists then do nothing.
addSessionToChat :: SessionID -> Chat -> Chat
addSessionToChat sid (n,ss) | sid `elem` ss = (n,ss)
                            | otherwise     = (n,sid:ss)

-- | Removes a SessinID from a chat. If SessionID doesnt' exists then do nothing.
removeSessionFromChat :: SessionID -> Chat -> Chat
removeSessionFromChat sid (n,ss) = (n, delete sid ss)

sendMessage :: Name -> ChatMessage -> [Chat] -> [ClientEntry] -> IO ()
sendMessage chatName msg@(ChatMessage sid message) cs ps = do
  case lookup chatName cs of
    Nothing -> return ()
    Just sids -> do
      let clientEntries = map (`lookupClientEntry` ps) sids
      let channels = map chatChannel $ catMaybes clientEntries
      mapM_ (`CC.writeChan` msg) channels
      return ()