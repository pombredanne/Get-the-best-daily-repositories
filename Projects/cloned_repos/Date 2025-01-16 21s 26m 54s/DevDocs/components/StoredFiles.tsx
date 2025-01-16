'use client'

import { useEffect, useState } from 'react'
import { Button } from "@/components/ui"
import LanguageIcon from '@mui/icons-material/Language'
import DescriptionIcon from '@mui/icons-material/Description'
import StorageIcon from '@mui/icons-material/Storage'
import AccessTimeIcon from '@mui/icons-material/AccessTime'
import DownloadIcon from '@mui/icons-material/Download'
import DataObjectIcon from '@mui/icons-material/DataObject'

interface StoredFile {
  name: string
  jsonPath: string
  markdownPath: string
  timestamp: Date
  size: number
  wordCount: number
  charCount: number
}

export default function StoredFiles() {
  const [files, setFiles] = useState<StoredFile[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    const listFiles = async () => {
      try {
        const response = await fetch('/api/storage')
        if (!response.ok) throw new Error('Failed to fetch files')
        const data = await response.json()
        setFiles(data.files)
      } catch (error) {
        console.error('Error loading stored files:', error)
      } finally {
        setIsLoading(false)
      }
    }

    // Initial load
    listFiles()

    // Set up polling for updates
    const interval = setInterval(listFiles, 2000)

    // Cleanup interval on unmount
    return () => clearInterval(interval)
  }, [])

  const handleDownload = (path: string, type: 'json' | 'markdown') => {
    const a = document.createElement('a')
    a.href = `/api/storage/download?path=${encodeURIComponent(path)}`
    a.download = path.split('/').pop() || `content.${type === 'json' ? 'json' : 'md'}`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
  }

  const formatProjectName = (name: string) => {
    // Remove common URL parts and clean up
    return name
      .replace(/^docs[._]/, '')  // Remove leading docs
      .replace(/[._]/g, ' ')     // Replace dots and underscores with spaces
      .split('/')                // Split by slashes
      .filter(Boolean)           // Remove empty parts
      .map(part =>              // Capitalize each part
        part.charAt(0).toUpperCase() + part.slice(1)
      )
      .join(' - ')              // Join with dashes
  }

  if (isLoading) {
    return (
      <div className="rounded-lg border border-gray-800 bg-gray-900/50 backdrop-blur-sm p-8">
        <div className="flex flex-col items-center justify-center text-gray-400 gap-2">
          <StorageIcon className="w-8 h-8 text-gray-600 animate-pulse" />
          <span className="animate-pulse">Loading stored files...</span>
          <div className="flex gap-1.5 mt-2">
            <div className="w-1.5 h-1.5 rounded-full bg-gray-600 animate-bounce" style={{ animationDelay: '0ms' }} />
            <div className="w-1.5 h-1.5 rounded-full bg-gray-600 animate-bounce" style={{ animationDelay: '150ms' }} />
            <div className="w-1.5 h-1.5 rounded-full bg-gray-600 animate-bounce" style={{ animationDelay: '300ms' }} />
          </div>
        </div>
      </div>
    )
  }

  if (files.length === 0) {
    return (
      <div className="text-center text-gray-400 py-8">
        No stored files found
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="rounded-lg border border-gray-800 overflow-hidden bg-gray-900/40 backdrop-blur-sm shadow-lg shadow-black/10">
        <table className="w-full">
          <thead className="bg-gray-800/60 border-b border-gray-800/60 backdrop-blur-sm">
            <tr>
              <th className="px-4 py-3 text-left">
                <div className="flex items-center gap-1.5">
                  <LanguageIcon className="w-4 h-4 text-blue-400" />
                  <span className="text-sm font-medium text-gray-300">Project Name</span>
                </div>
              </th>
              <th className="px-4 py-3 text-left">
                <div className="flex items-center gap-1.5">
                  <DescriptionIcon className="w-4 h-4 text-green-400" />
                  <span className="text-sm font-medium text-gray-300">Words</span>
                </div>
              </th>
              <th className="px-4 py-3 text-left">
                <div className="flex items-center gap-1.5">
                  <StorageIcon className="w-4 h-4 text-white" />
                  <span className="text-sm font-medium text-gray-300">Size</span>
                  <span className="text-xs text-gray-500">(KB)</span>
                </div>
              </th>
              <th className="px-4 py-3 text-left">
                <div className="flex items-center gap-1.5">
                  <AccessTimeIcon className="w-4 h-4 text-purple-400" />
                  <span className="text-sm font-medium text-gray-300">Last Updated</span>
                </div>
              </th>
              <th className="px-4 py-3 text-right">
                <div className="flex items-center justify-end gap-1.5">
                  <DownloadIcon className="w-4 h-4 text-blue-400" />
                  <span className="text-sm font-medium text-gray-300">Download</span>
                </div>
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-800">
            {files.map((file) => (
              <tr key={file.name} className="group hover:bg-gray-800/40 transition-all duration-200 ease-in-out">
                <td className="px-6 py-4">
                  <span className="text-gray-300 font-medium">
                    {formatProjectName(file.name)}
                  </span>
                </td>
                <td className="px-6 py-4 text-gray-300">
                  {file.wordCount.toLocaleString()}
                </td>
                <td className="px-6 py-4 text-gray-300">
                  {(file.size / 1024).toFixed(1)}
                </td>
                <td className="px-6 py-4 text-gray-400 text-sm">
                  {new Intl.DateTimeFormat('en-US', {
                    month: 'short',
                    day: 'numeric',
                    hour: 'numeric',
                    minute: 'numeric',
                    hour12: true
                  }).format(new Date(file.timestamp))}
                </td>
                <td className="px-4 py-3">
                  <div className="flex items-center justify-end gap-3">
                    <Button
                      onClick={() => handleDownload(file.jsonPath, 'json')}
                      variant="outline"
                      size="icon"
                      title="Download as JSON data"
                      className="h-8 w-8 bg-gray-800/50 hover:bg-yellow-500/20 border-yellow-400/20 hover:border-yellow-400/40 transition-all duration-200 ease-in-out transform hover:scale-105"
                    >
                      <DataObjectIcon className="w-4 h-4 text-yellow-400" />
                    </Button>
                    <Button
                      onClick={() => handleDownload(file.markdownPath, 'markdown')}
                      variant="outline"
                      size="icon"
                      title="Download Markdown"
                      className="h-8 w-8 bg-gray-800 hover:bg-sky-500/20 border-sky-400/20 hover:border-sky-400/40"
                    >
                      <DescriptionIcon className="w-5 h-5 text-white" />
                    </Button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}