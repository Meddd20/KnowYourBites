# KnowYourBites 📸🥡

An IOS application that helps you analyze composition and nutrition facts of a product by extracting information with OCR and summarize it with Gemini LLM

---

## Features ✨
- **Camera Integration**
    - Capture photos with live preview
    - Torch support
    - Tap-to-focus
    - Gallery access

- **OCR with Vision**
    - Extract nutrition facts and composition text from packaging while ensuring the original line structure is retained to avoid breaking the contextual meaning

- **LLM Integration**
    - Validate extracted OCR texts
    - Re-structured nutrition and composition data
    - Summarize product based on nutrition facts and composition
    - Add a fun roast criticized the product

## Tech Stack 🛠
- **UIKit** (programmatic UI)
- **AVFoundation** (Camera capture, torch, focus)
- **Vision** (OCR text recognition)
- **FirebaseAI (Gemini)** (LLM validation & summary)

## Architecture 🏗
The app follows **MVVM Architecture**
- **Model** → OCR result, nutrition & composition struct, Gemini responses
- **View** → UIKit `UIViewController` (Camera, Loading, Summary)
- **ViewModel** → Not Yet


