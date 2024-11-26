﻿// Copyright 2024 N-GINN LLC. All rights reserved.
// Use of this source code is governed by a BSD-3 Clause license that can be found in the LICENSE file.
//
// Undo/redo system for usd stage.

#pragma once

#include "nau/nau_usd_asset_editor_common_config.hpp"
#include "nau/undo-redo/nau_usd_scene_commands.hpp"

#include "pxr/usd/usd/stage.h"
#include "commands/nau_commands.hpp"

#include <string>


// ** NauUsdSceneUndoRedoSystem

class NAU_USD_ASSET_EDITOR_COMMON_API NauUsdSceneUndoRedoSystem
{
public:
    NauUsdSceneUndoRedoSystem(NauUndoable* undoRedoSystem);

    template<std::derived_from<NauAbstractUsdSceneCommand> T, bool execute = true, typename... Args>
    void addCommand(Args&&... args);
    void groupBegin(size_t commandsCount);

    void bindCurrentScene(pxr::UsdStageRefPtr currentScene);
    void unbindCurrentScene();

private:
    pxr::UsdStageRefPtr m_currentScene;
    NauUndoable* m_undoRedoSystem = nullptr;
};

using NauUsdSceneUndoRedoSystemPtr = std::shared_ptr<NauUsdSceneUndoRedoSystem>;


template<std::derived_from<NauAbstractUsdSceneCommand> T, bool execute, typename... Args>
void NauUsdSceneUndoRedoSystem::addCommand(Args&&... args)
{
    m_undoRedoSystem->addCommand<T, execute>(m_currentScene, std::forward<Args>(args)...);
}
