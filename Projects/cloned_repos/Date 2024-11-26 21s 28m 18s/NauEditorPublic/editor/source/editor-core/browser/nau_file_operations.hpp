// Copyright 2024 N-GINN LLC. All rights reserved.
// Use of this source code is governed by a BSD-3 Clause license that can be found in the LICENSE file.
//
// Base file system items operations.

#pragma once

#include "nau/nau_editor_config.hpp"

#include <QModelIndexList>


// ** NauFileOperations

class NAU_EDITOR_API NauFileOperations
{
public:
    static void copyToClipboard(const QModelIndexList& indexes);
    static void cutToClipboard(const QModelIndexList& indexes);
    static void pasteFromClipboard(const QModelIndex& parent);

    // Moves specified path to trash. 
    static bool deletePathRecursively(const QString& path);

    static void duplicate(const QModelIndexList& indexes);

    // Returns available file name if specified exists.
    // New file name is generated via generateFileName().
    static QString generateFileNameIfExists(const QString& absFilePath);

    // Copy directory from src to dst with respect to src structure.
    // Set overwrite if directory/file should be replaced if it does exist in dst directory.
    // Returns false on failure on any item's copying.
    static bool copyPathRecursively(const QString& src, const QString& dst, bool overwrite = false);

    // Appends the counter to baseFileName with respect to extension and file name.
    // 'some file.txt' -> some file(1).txt'
    // some file(1).txt' -> some file(2).txt'
    static QString generateFileName(const QString& baseFileName);

private:
    static QString cutOperationMimeType();
    static QByteArray copyDropEffectData();
    static QByteArray cutDropEffectData();

    static QMimeData* prepareCopyCut(const QModelIndexList& indexes);
    static bool movePathRecursively(const QString& src, const QString& dst);
};
