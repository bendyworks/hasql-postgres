-- |
-- Backend-aware parsed results' handlers.
module Hasql.Postgres.ResultHandler where

import Hasql.Postgres.Prelude
import qualified Hasql.Backend as Backend
import qualified Hasql.Postgres.ResultParser as Result
import qualified Hasql.Postgres.ErrorCode as ErrorCode


type ResultHandler a =
  Result.Result -> IO a

{-# INLINE unit #-}
unit :: ResultHandler ()
unit =
  resultHandler $ \case
    Result.CommandOK _ -> Right $ return ()
    _ -> Left "Not a unit"

{-# INLINE rowsStream #-}
rowsStream :: ResultHandler Result.RowsStream
rowsStream =
  resultHandler $ \case
    Result.Rows s _ _ -> Right s
    _ -> Left "Not a rows result"

{-# INLINE rowsVector #-}
rowsVector :: ResultHandler Result.RowsVector
rowsVector =
  resultHandler $ \case
    Result.Rows _ v _ -> Right v
    _ -> Left "Not a rows result"

{-# INLINE rowsList #-}
rowsList :: ResultHandler Result.RowsList
rowsList =
  resultHandler $ \case
    Result.Rows _ _ l -> Right l
    _ -> Left "Not a rows result"

{-# INLINE rowsAffected #-}
rowsAffected :: ResultHandler ByteString
rowsAffected =
  resultHandler $ \case
    Result.CommandOK (Just v) -> Right $ return v
    _ -> Left "Not a number of affected rows"

{-# INLINE resultHandler #-}
resultHandler :: (Result.Result -> Either Text (IO a)) -> ResultHandler a
resultHandler partial result =
  case partial result of
    Right io -> 
      io
    Left text -> 
      -- Handle erroneous results with unexpected result as a fallback.
      case result of
        Result.StatusError _ c _ _ _ | elem c codes ->
          throwIO Backend.TransactionConflict
          where
            codes =
              [
                ErrorCode.transaction_rollback,
                ErrorCode.transaction_integrity_constraint_violation,
                ErrorCode.serialization_failure,
                ErrorCode.statement_completion_unknown,
                ErrorCode.deadlock_detected
              ]
        _ ->
          maybe
            (throwIO $ Backend.UnexpectedResult text)
            (throwIO . Backend.ErroneousResult)
            (Result.erroneousResultText result)


