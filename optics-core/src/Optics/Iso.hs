module Optics.Iso
  ( An_Iso
  , Iso
  , Iso'
  , toIso
  , iso
  , withIso
  , au
  , under
  -- * Isomorphisms
  , mapping
  , coerced
  , coerced'
  , coerced1
  , curried
  , uncurried
  , flipped
  , involuted
  , Swapped(..)
  -- * Re-exports
  , module Optics.Optic
  )
  where

import Data.Tuple
import Data.Bifunctor
import Data.Coerce

import Optics.Internal.Concrete
import Optics.Internal.Optic
import Optics.Internal.Profunctor
import Optics.Optic

-- | Type synonym for a type-modifying iso.
type Iso s t a b = Optic An_Iso NoIx s t a b

-- | Type synonym for a type-preserving iso.
type Iso' s a = Optic' An_Iso NoIx s a

-- | Explicitly cast an optic to an iso.
toIso :: Is k An_Iso => Optic k is s t a b -> Optic An_Iso is s t a b
toIso = castOptic
{-# INLINE toIso #-}

-- | Build an iso from a pair of inverse functions.
iso :: (s -> a) -> (b -> t) -> Iso s t a b
iso f g = Optic (dimap f g)
{-# INLINE iso #-}

-- | Extract the two components of an isomorphism.
withIso :: Is k An_Iso => Optic k is s t a b -> ((s -> a) -> (b -> t) -> r) -> r
withIso o k = case getOptic (toIso o) (Exchange id id) of
  Exchange sa bt -> k sa bt
{-# INLINE withIso #-}

-- | Based on @ala@ from Conor McBride's work on Epigram.
--
-- This version is generalized to accept any 'Iso', not just a @newtype@.
--
-- >>> au (coerced1 @Sum) foldMap [1,2,3,4]
-- 10
--
-- You may want to think of this combinator as having the following, simpler
-- type:
--
-- @
-- au :: Iso s t a b -> ((b -> t) -> e -> s) -> e -> a
-- @
au :: (Is k An_Iso, Functor f) => Optic k is s t a b -> ((b -> t) -> f s) -> f a
au k = withIso k $ \sa bt f -> sa <$> f bt
{-# INLINE au #-}

-- | The opposite of working 'Optics.Setter.over' a 'Optics.Setter.Setter' is
-- working 'under' an isomorphism.
--
-- @
-- 'under' ≡ 'Optics.Setter.over' '.' 'Optics.Re.re'
-- @
under :: Is k An_Iso => Optic k is s t a b -> (t -> s) -> b -> a
under k = withIso k $ \sa bt ts -> sa . ts . bt
{-# INLINE under #-}

----------------------------------------
-- Isomorphisms

-- | This can be used to lift any 'Iso' into an arbitrary 'Functor'.
mapping
  :: (Is k An_Iso, Functor f, Functor g)
  => Optic k is s t a b
  -> Iso (f s) (g t) (f a) (g b)
mapping k = withIso k $ \sa bt -> iso (fmap sa) (fmap bt)
{-# INLINE mapping #-}

-- | Data types that are representationally equal are isomorphic.
--
-- >>> view coerced 'x' :: Identity Char
-- Identity 'x'
--
coerced :: (Coercible s a, Coercible t b) => Iso s t a b
coerced = Optic (lcoerce' . rcoerce')
{-# INLINE coerced #-}

-- | Type-preserving version of 'coerced'.
--
-- >>> newtype MkInt = MkInt Int deriving Show
--
-- >>> over (coerced' @MkInt @Int) (*3) (MkInt 2)
-- MkInt 6
--
coerced' :: Coercible s a => Iso' s a
coerced' = Optic (lcoerce' . rcoerce')
{-# INLINE coerced' #-}

-- | Special case of 'coerced' for trivial newtype wrappers.
--
-- >>> over (coerced1 @Identity) (++ "bar") (Identity "foo")
-- Identity "foobar"
--
coerced1
  :: forall f s a. (Coercible s (f s), Coercible a (f a))
  => Iso (f s) (f a) s a
coerced1 = Optic (lcoerce' . rcoerce')
{-# INLINE coerced1 #-}

-- | The canonical isomorphism for currying and uncurrying a function.
--
-- @
-- 'curried' = 'iso' 'curry' 'uncurry'
-- @
--
-- >>> view curried fst 3 4
-- 3
--
curried :: Iso ((a, b) -> c) ((d, e) -> f) (a -> b -> c) (d -> e -> f)
curried = iso curry uncurry
{-# INLINE curried #-}

-- | The canonical isomorphism for uncurrying and currying a function.
--
-- @
-- 'uncurried' = 'iso' 'uncurry' 'curry'
-- @
--
-- @
-- 'uncurried' = 're' 'curried'
-- @
--
-- >>> (view uncurried (+)) (1,2)
-- 3
--
uncurried :: Iso (a -> b -> c) (d -> e -> f) ((a, b) -> c) ((d, e) -> f)
uncurried = iso uncurry curry
{-# INLINE uncurried #-}

-- | The isomorphism for flipping a function.
--
-- >>> (view flipped (,)) 1 2
-- (2,1)
--
flipped :: Iso (a -> b -> c) (a' -> b' -> c') (b -> a -> c) (b' -> a' -> c')
flipped = iso flip flip
{-# INLINE flipped #-}

-- | Given a function that is its own inverse, this gives you an 'Iso' using it
-- in both directions.
--
-- @
-- 'involuted' ≡ 'Control.Monad.join' 'iso'
-- @
--
-- >>> "live" ^. involuted reverse
-- "evil"
--
-- >>> "live" & involuted reverse %~ ('d':)
-- "lived"
involuted :: (a -> a) -> Iso' a a
involuted a = iso a a
{-# INLINE involuted #-}

-- | This class provides for symmetric bifunctors.
class Bifunctor p => Swapped p where
  -- |
  -- @
  -- 'swapped' '.' 'swapped' ≡ 'id'
  -- 'first' f '.' 'swapped' = 'swapped' '.' 'second' f
  -- 'second' g '.' 'swapped' = 'swapped' '.' 'first' g
  -- 'bimap' f g '.' 'swapped' = 'swapped' '.' 'bimap' g f
  -- @
  --
  -- >>> view swapped (1,2)
  -- (2,1)
  --
  swapped :: Iso (p a b) (p c d) (p b a) (p d c)

instance Swapped (,) where
  swapped = iso swap swap
  {-# INLINE swapped #-}

instance Swapped Either where
  swapped = iso (either Right Left) (either Right Left)
  {-# INLINE swapped #-}

-- $setup
-- >>> import Optics.Core
-- >>> import Data.Functor.Identity
