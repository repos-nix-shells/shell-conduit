{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE StandaloneDeriving #-}

-- | All types.

module Data.Conduit.Shell.Types where

import Control.Applicative
import Control.Exception
import Control.Monad
import Control.Monad.Base
import Control.Monad.IO.Class
import Control.Monad.Trans.Class
import Control.Monad.Trans.Control
import Control.Monad.Trans.Resource
import Data.ByteString (ByteString)
import Data.Conduit
import Data.Typeable

-- | A chunk, either stdout/stdin or stderr. Used for both input and
-- output.
type Chunk = Either ByteString ByteString

-- | Either stdout or stderr.
data ChunkType
  = Stderr -- ^ Stderr.
  | Stdout -- ^ Stdin or stdout.
  deriving (Eq,Enum,Bounded)

-- | Shell transformer.
newtype ShellT m a =
  ShellT {runShellT :: ResourceT m a}
  deriving (Applicative,Monad,Functor,MonadThrow,MonadIO,MonadTrans)

deriving instance (MonadResourceBase m) => MonadBase IO (ShellT m)
deriving instance (MonadResourceBase m) => MonadResource (ShellT m)

-- | Dumb instance.
instance (MonadThrow m,MonadIO m,MonadBaseControl IO m) => MonadBaseControl IO (ShellT m) where
  newtype StM (ShellT m) a = StMShell{unStMGeoServer ::
                                    StM (ResourceT m) a}
  liftBaseWith f =
    ShellT (liftBaseWith
              (\run ->
                 f (liftM StMShell .
                    run .
                    runShellT)))
  restoreM = ShellT . restoreM . unStMGeoServer

-- | Intentionally only handles 'ShellException'. Use normal exception
-- handling to handle usual exceptions.
instance (MonadBaseControl IO (ShellT m),Applicative m,MonadThrow m) => Alternative (ConduitM i o (ShellT m)) where
  empty = monadThrow ShellEmpty
  x <|> y =
    do r <- tryC x
       case r of
         Left (_ :: ShellException) -> y
         Right rr -> return rr

-- | An exception resulting from a shell command.
data ShellException
  = ShellEmpty -- ^ For 'mempty'.
  | ShellExitFailure !Int -- ^ Process exited with failure.
  deriving (Typeable,Show)
instance Exception ShellException
