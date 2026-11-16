# MediaPipe proto classes referenced via reflection/JNI
-keep class com.google.mediapipe.proto.** { *; }
-keep class com.google.mediapipe.framework.** { *; }

# MediaPipe tasks
-keep class com.google.mediapipe.tasks.** { *; }
-keep class org.tensorflow.** { *; }
-dontwarn com.google.mediapipe.proto.**
-dontwarn com.google.mediapipe.framework.**
