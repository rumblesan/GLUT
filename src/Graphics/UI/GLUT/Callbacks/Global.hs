--------------------------------------------------------------------------------
-- |
-- Module      :  Graphics.UI.GLUT.Callbacks.Global
-- Copyright   :  (c) Sven Panne 2002-2013
-- License     :  BSD3
--
-- Maintainer  :  Sven Panne <svenpanne@gmail.com>
-- Stability   :  stable
-- Portability :  portable
--
--------------------------------------------------------------------------------

module Graphics.UI.GLUT.Callbacks.Global (
   -- * Menu status callback
   MenuUsage(..), MenuStatusCallback, menuStatusCallback,

   -- * Idle callback
   IdleCallback, idleCallback,

   -- * Timer callbacks
   Timeout, TimerCallback, addTimerCallback
) where

import Control.Monad.Fix ( mfix )
import Data.StateVar ( SettableStateVar, makeSettableStateVar )
import Foreign.C.Types ( CInt )
import Graphics.Rendering.OpenGL ( Position(..) )

import Graphics.UI.GLUT.Callbacks.Registration
import Graphics.UI.GLUT.Raw

--------------------------------------------------------------------------------

data MenuUsage
   = NotInUse
   | InUse
   deriving ( Eq, Ord, Show )

unmarshalMenuUsage :: CInt -> MenuUsage
unmarshalMenuUsage x
   | x == glut_MENU_NOT_IN_USE = NotInUse
   | x == glut_MENU_IN_USE = InUse
   | otherwise = error ("unmarshalMenuUsage: illegal value " ++ show x)

type MenuStatusCallback  = MenuUsage -> Position -> IO ()

-- | Controls the global menu status callback so a GLUT program can determine
-- when a menu is in use or not. When a menu status callback is registered, it
-- will be called with the value 'InUse' when pop-up menus are in use by the
-- user; and the callback will be called with the value 'NotInUse' when pop-up
-- menus are no longer in use. Additionally, the location in window coordinates
-- of the button press that caused the menu to go into use, or the location where
-- the menu was released (maybe outside the window). Other callbacks continue to
-- operate (except mouse motion callbacks) when pop-up menus are in use so the
-- menu status callback allows a program to suspend animation or other tasks
-- when menus are in use. The cascading and unmapping of sub-menus from an
-- initial pop-up menu does not generate menu status callbacks. There is a
-- single menu status callback for GLUT.
--
-- When the menu status callback is called, the /current menu/ will be set to
-- the initial pop-up menu in both the 'InUse' and 'NotInUse' cases. The
-- /current window/ will be set to the window from which the initial menu was
-- popped up from, also in both cases.

menuStatusCallback :: SettableStateVar (Maybe MenuStatusCallback)
menuStatusCallback =
   makeSettableStateVar $
      setCallback MenuStatusCB glutMenuStatusFunc
                  (makeMenuStatusFunc . unmarshal)
   where unmarshal cb s x y =
            cb (unmarshalMenuUsage s)
               (Position (fromIntegral x) (fromIntegral y))

--------------------------------------------------------------------------------

type IdleCallback = IO ()

-- | Controls the global idle callback so a GLUT program can perform background
-- processing tasks or continuous animation when window system events are not
-- being received. If enabled, the idle callback is continuously called when
-- events are not being received. The /current window/ and /current menu/ will
-- not be changed before the idle callback. Programs with multiple windows
-- and\/or menus should explicitly set the /current window/ and\/or /current
-- menu/ and not rely on its current setting.
--
-- The amount of computation and rendering done in an idle callback should be
-- minimized to avoid affecting the program\'s interactive response. In general,
-- not more than a single frame of rendering should be done in an idle callback.

idleCallback :: SettableStateVar (Maybe IdleCallback)
idleCallback =
   makeSettableStateVar $ setCallback IdleCB glutIdleFunc makeIdleFunc

--------------------------------------------------------------------------------

-- | Timeout for the timer callback in milliseconds
type Timeout = Int

type TimerCallback  = IO ()

-- | Register a one-shot timer callback to be triggered after at least the given
-- amount of time. Multiple timer callbacks at same or differing times may be
-- registered simultaneously. There is no support for canceling a registered
-- callback.
--
-- The number of milliseconds is a lower bound on the time before the callback
-- is generated. GLUT attempts to deliver the timer callback as soon as possible
-- after the expiration of the callback\'s time interval.

addTimerCallback :: Timeout -> TimerCallback -> IO ()
addTimerCallback msecs timerCallback = do
   funPtr <- mfix (\self -> makeTimerFunc (\_ -> do registerForCleanup self
                                                    timerCallback))
   glutTimerFunc (fromIntegral msecs) funPtr 0
