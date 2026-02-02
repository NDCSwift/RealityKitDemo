//
        //
    //  Project: ARKitDemo
    //  File: ARViewContainer.swift
    //  Created by Noah Carpenter 
    //
    //  📺 YouTube: Noah Does Coding
    //  https://www.youtube.com/@NoahDoesCoding97
    //  Like and Subscribe for coding tutorials and fun! 💻✨
    //  Dream Big. Code Bigger 🚀
    //

import SwiftUI
import RealityKit
import ARKit

// ARViewContainer bridges a RealityKit ARView into SwiftUI and handles tap/pinch gestures to place and scale a 3D model.

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        // Create the RealityKit ARView that renders the AR scene
        let arView = ARView(frame: .zero)
        
        // Configure world tracking (6DOF) with plane detection and optional scene reconstruction
        let config = ARWorldTrackingConfiguration()
        
        // Detect horizontal planes (tables, floors). Add .vertical if you need walls
        config.planeDetection = [.horizontal]
        
        // Enable scene reconstruction (meshing) when available for improved understanding/occlusion
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        // Start the AR session with our configuration
        arView.session.run(config)
        
        // Add a tap gesture recognizer to place the model on a detected surface
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        // Add a pinch gesture recognizer to scale the last-placed model
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        arView.addGestureRecognizer(pinchGesture)
        
        // Return the configured ARView to SwiftUI
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // No dynamic updates needed for now; ARView is driven by gestures and ARSession
    }
    
    // Create a coordinator to act as the target for UIKit gestures and hold transient AR state
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        // Holds references to the selected entity and implements gesture handlers for placing/scaling
        
        // Most recently placed model to apply scaling
        var selectedEntity: ModelEntity?
        // Scale captured at the beginning of a pinch gesture
        var initialScale: SIMD3<Float> = [0.01, 0.01, 0.01]
        
        // Clamp scaling so the model stays within a reasonable size range
        let minScale: Float = 0.01
        let maxScale: Float = 0.02
        
        // tap gesture
        
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            // Ensure the gesture is attached to an ARView
            guard let arView = recognizer.view as? ARView else { return }
            
            // Screen-space location of the tap
            let tapLocation = recognizer.location(in: arView)
            
            // Raycast from the tap into the real world to find a horizontal surface
            let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)
            
            // If no surface was found, guide the user
            guard let firstResult = results.first else {
                print("No surface was found - point camera at flat surface")
                return
            }
            
            // Load the 3D model from the app bundle (robot.usdz)
            guard let modelEntity = try? ModelEntity.loadModel(named: "robot") else {
                print("Failed to load 3D model. check that robot.usdz is in your project")
                return
            }
            
            // Set an initial (small) scale and enable collisions for interactions
            modelEntity.scale = [0.01, 0.01, 0.01]
            modelEntity.generateCollisionShapes(recursive: true)
            
            // Create an anchor at the raycast's world transform so the model stays tracked in space
            let anchorEntity = AnchorEntity(world: firstResult.worldTransform)
            
            // Attach the model to the anchor and add it to the scene
            anchorEntity.addChild(modelEntity)
            arView.scene.addAnchor(anchorEntity)
            
            // Remember this entity so pinch can scale it
            selectedEntity = modelEntity
            
            print("Placed the model - pinch to scale")
            
        }
        
        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer){
            
            // Require a selected entity to scale (tap to place one first)
            guard let entity = selectedEntity else {
                print("No entity is selected tap to place an object first")
                return
            }
            
            // Track the gesture lifecycle to compute relative scaling
            switch recognizer.state {
            case .began:
                // Capture the starting scale at gesture begin
                initialScale = entity.scale
                print("Started scaling from \(initialScale)")
                
            case .changed:
                // Apply the gesture's scale factor relative to the initial scale
                let scale = Float(recognizer.scale)
                let newScale = initialScale * scale
                
                // Clamp the new scale to the allowed range
                let clampedScale = SIMD3<Float>(
                    x: max(minScale, min(maxScale, newScale.x)),
                    y: max(minScale, min(maxScale, newScale.y)),
                    z: max(minScale, min(maxScale, newScale.z))
                )
                entity.scale = clampedScale
                
            case .ended:
                // Gesture ended; keep the resulting scale
                print("final scale \(entity.scale)")
                
            case .cancelled:
                // Revert to the original scale if the gesture was cancelled
                entity.scale = initialScale
                print("Scale cancelled")
                
            default: break
                
            }
        }
        
    }
    
}

