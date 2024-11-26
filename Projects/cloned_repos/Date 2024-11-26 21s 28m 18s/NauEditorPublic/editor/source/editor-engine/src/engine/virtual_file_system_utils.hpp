// Copyright 2024 N-GINN LLC. All rights reserved.
// Use of this source code is governed by a BSD-3 Clause license that can be found in the LICENSE file.

#pragma once

#include "nau/io/virtual_file_system.h"
#include <filesystem>


namespace editor::vfsUtils
{
    void configureVirtualFileSystem(nau::io::IVirtualFileSystem& vfs, const std::string& rootPath)
    {
        namespace fs = std::filesystem;
        const eastl::vector<std::pair<const char*, fs::path>> contentRelativePaths = {
            {"/content", {L"content"}},
            {"/res"    , {L"resources"}},
            {"/project", rootPath},
        };
        
        for (auto& [name, contentRelativePath] : contentRelativePaths)
        {
            const auto projectContentDir = EXPR_Block->fs::path
            {
                fs::path currentPath = rootPath;
                do
                {
                    auto targetPath = currentPath / contentRelativePath;
                    if (fs::exists(targetPath))
                    {
                        return fs::canonical(targetPath);
                    }

                    currentPath = currentPath.parent_path();

                } while (currentPath.has_relative_path());

                return {};
            };

            auto contentFs = nau::io::createNativeFileSystem(projectContentDir.string());
            vfs.mount(name, std::move(contentFs)).ignore();
        }

        // Mount assets database
        const auto assetsDbDir = fs::path(rootPath) / "assets_database";
        if (!fs::exists(assetsDbDir)) {
            fs::create_directories(assetsDbDir);
        }
        auto assetsDBFs = nau::io::createNativeFileSystem(assetsDbDir.string());
        vfs.mount("/assets_database", std::move(assetsDBFs)).ignore();
    }
}
