import React, { useState, useCallback } from 'react';
import { Image, Trash2 } from 'lucide-react';
import { CompressionOptions } from './components/CompressionOptions';
import { DropZone } from './components/DropZone';
import { ImageList } from './components/ImageList';
import { DownloadAll } from './components/DownloadAll';
import { useImageProcessing } from './hooks/useImageProcessing';
import { DEFAULT_QUALITY_SETTINGS } from './utils/formatDefaults';
import type { ImageFile, OutputType, CompressionOptions as CompressionOptionsType } from './types';

export function App() {
  const [images, setImages] = useState<ImageFile[]>([]);
  const [outputType, setOutputType] = useState<OutputType>('webp');
  const [options, setOptions] = useState<CompressionOptionsType>({
    quality: DEFAULT_QUALITY_SETTINGS.webp,
  });

  const { processImage } = useImageProcessing(options, outputType, setImages);

  const handleOutputTypeChange = useCallback((type: OutputType) => {
    setOutputType(type);
    if (type !== 'png') {
      setOptions({ quality: DEFAULT_QUALITY_SETTINGS[type] });
    }
  }, []);

  const handleFilesDrop = useCallback((newImages: ImageFile[]) => {
    setImages((prev) => [...prev, ...newImages]);
    newImages.forEach(processImage);
  }, [processImage]);

  const handleRemoveImage = useCallback((id: string) => {
    setImages((prev) => {
      const image = prev.find(img => img.id === id);
      if (image?.preview) {
        URL.revokeObjectURL(image.preview);
      }
      return prev.filter(img => img.id !== id);
    });
  }, []);

  const handleClearAll = useCallback(() => {
    images.forEach(image => {
      if (image.preview) {
        URL.revokeObjectURL(image.preview);
      }
    });
    setImages([]);
  }, [images]);

  const handleDownloadAll = useCallback(() => {
    const completedImages = images.filter(img => img.status === 'complete');
    completedImages.forEach(image => {
      if (image.blob && image.outputType) {
        const link = document.createElement('a');
        link.href = URL.createObjectURL(image.blob);
        link.download = `${image.file.name.split('.')[0]}.${image.outputType}`;
        link.click();
        URL.revokeObjectURL(link.href);
      }
    });
  }, [images]);

  const completedImages = images.filter(img => img.status === 'complete').length;

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 py-12">
        <div className="text-center mb-8">
          <div className="flex items-center justify-center gap-2 mb-4">
            <Image className="w-8 h-8 text-blue-500" />
            <h1 className="text-3xl font-bold text-gray-900">Squish</h1>
          </div>
          <p className="text-gray-600">
            Compress and convert your images to AVIF, JPEG, JPEG XL, PNG, or WebP
          </p>
        </div>

        <div className="space-y-6">
          <CompressionOptions
            options={options}
            outputType={outputType}
            onOptionsChange={setOptions}
            onOutputTypeChange={handleOutputTypeChange}
          />

          <DropZone onFilesDrop={handleFilesDrop} />

          {completedImages > 0 && (
            <DownloadAll onDownloadAll={handleDownloadAll} count={completedImages} />
          )}

          <ImageList 
            images={images} 
            onRemove={handleRemoveImage} 
          />

          {images.length > 0 && (
            <button
              onClick={handleClearAll}
              className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
            >
              <Trash2 className="w-5 h-5" />
              Clear All
            </button>
          )}
        </div>
      </div>
    </div>
  );
}