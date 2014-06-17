{-# LANGUAGE TemplateHaskell, GADTs, FlexibleInstances #-}

-- |
-- Module      : Language.C.Inline.ObjC.Hint
-- Copyright   : 2014 Manuel M T Chakravarty
-- License     : BSD3
--
-- Maintainer  : Manuel M T Chakravarty <chak@justtesting.org>
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)
--
-- This module provides Objective-C specific hints.

module Language.C.Inline.ObjC.Hint (
  -- * Class hints
  Class(..), IsType
) where

  -- standard libraries
import Language.Haskell.TH        as TH
import Language.Haskell.TH.Syntax as TH

  -- quasi-quotation libraries
import Language.C.Quote           as QC
import Language.C.Quote.ObjC      as QC

  -- friends
import Language.C.Inline.Error
import Language.C.Inline.Hint
import Language.C.Inline.TH


-- |Class of entities that can be used as TH types.
--
class IsType ty where
  theType :: ty -> Q TH.Type

instance IsType TH.Type where
  theType = return

instance IsType (Q TH.Type) where
  theType = id

instance IsType TH.Name where
  theType name
    = do
      { info <- reify name
      ; case info of
          TyConI _         -> return $ ConT name
          PrimTyConI _ _ _ -> return $ ConT name    
          FamilyI _ _      -> return $ ConT name
          _                -> 
            do
            { reportErrorAndFail QC.ObjC $ 
                "expected '" ++ show name ++ "' to be a type name, but it is " ++ 
                show (TH.ppr info)
            }
      }
  
-- |Hint indicating to marshal an Objective-C object as a foreign pointer, where the argument is the Haskell type
-- representing the Objective-C class. The Haskell type name must coincide with the Objective-C class name.
--
data Class where
  Class :: IsType t => t -> Class

instance Hint Class where
  haskellType (Class tyish) 
    = do
      { ty <- theType tyish
      ; foreignWrapperDatacon ty      -- FAILS if the declaration is not a 'ForeignPtr' wrapper
      ; return ty
      }
  foreignType (Class tyish)
    = do
      { name <- theType tyish >>= headTyConNameOrError
      ; return $ Just [cty| typename $id:(nameBase name) * |]
      }
  showQ (Class tyish) 
    = do
      { ty <- theType tyish
      ; return $ "Class " ++ show ty
      }

headTyConNameOrError :: TH.Type -> Q TH.Name
headTyConNameOrError ty
  = case headTyConName ty of
      Just name -> return name
      Nothing   -> reportErrorAndFail QC.ObjC $ "expected the head of '" ++ show ty ++ "' to be a type constructor"