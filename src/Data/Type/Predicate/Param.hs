{-# LANGUAGE DefaultSignatures    #-}
{-# LANGUAGE EmptyCase            #-}
{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE LambdaCase           #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE TypeApplications     #-}
{-# LANGUAGE TypeFamilies         #-}
{-# LANGUAGE TypeInType           #-}
{-# LANGUAGE TypeOperators        #-}
{-# LANGUAGE UndecidableInstances #-}

module Data.Type.Predicate.Param (
    ParamPred
  , Found, FlipPP, PPMap
  , Search(..), Search_(..)
  , AnyMatch
  ) where

import           Data.Singletons
import           Data.Singletons.Decide
import           Data.Singletons.Sigma
import           Data.Type.Predicate
import           Data.Type.Universe

-- | A parameterized predicate.
type ParamPred k v = k -> Predicate v

-- | Convert a parameterized predicate into a predicate on the parameter
data Found :: ParamPred k v -> Predicate k
type instance Apply (Found (p :: ParamPred k v)) a = Σ v (p a)

-- | Flip the arguments of a 'ParamPred'.
data FlipPP :: ParamPred v k -> ParamPred k v
type instance Apply (FlipPP p x) y = p y @@ x

-- | Pre-compose a function to a 'ParamPred'.  Is essentially @'flip'
-- ('.')@, but unfortunately defunctionalization doesn't work too well with
-- that definition.
data PPMap :: (k ~> j) -> ParamPred j v -> ParamPred k v
type instance Apply (PPMap f p x) y = p (f @@ x) @@ y

class Search p where
    search :: Test (Found p)

    default search :: Search_ p => Test (Found p)
    search = Proved . search_

class Search p => Search_ p where
    search_ :: Test_ (Found p)

instance Search p => Decide (Found p) where
    decide = search

instance Search_ p => Decide_ (Found p) where
    decide_ = search_

instance (Search (p :: ParamPred j v), SingI (f :: k ~> j)) => Search (PPMap f p) where
    search (x :: Sing a) = case search @p ((sing :: Sing f) @@ x) of
        Proved (i :&: p) -> Proved $ i :&: p
        Disproved v      -> Disproved $ \case i :&: p -> v (i :&: p)

instance (Search_ (p :: ParamPred j v), SingI (f :: k ~> j)) => Search_ (PPMap f p) where
    search_ (x :: Sing a) = case search_ @p ((sing :: Sing f) @@ x) of
        i :&: p -> i :&: p

-- | @'AnyMatch' f@ takes a parmaeterized predicate on @k@ (testing for
-- a @v@) and turns it into a parameterized predicate on @f k@ (testing for
-- a @v@).
--
-- An @'AnyMatch' f p as@ is a predicate taking an argument @a@ and
-- testing if @p a :: 'Predicate' k@ is satisfied for any item in @as ::
-- f k@.
--
-- A @'ParamPred' k v@ tests if a @k@ can create some @v@.  The resulting
-- @'Param' (f k) v@ tests if any @k@ in @f k@ can create some @v@.
data AnyMatch f :: ParamPred k v -> ParamPred (f k) v
type instance Apply (AnyMatch f p as) a = Any f (FlipPP p a) @@ as

instance (Universe f, Search p) => Search (AnyMatch f p) where
    search xs = case decide @(Any f (Found p)) xs of
      Proved (WitAny i (x :&: p)) -> Proved $ x :&: WitAny i p
      Disproved v                 -> Disproved $ \case
        x :&: WitAny i p -> v $ WitAny i (x :&: p)

