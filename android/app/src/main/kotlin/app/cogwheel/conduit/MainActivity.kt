package app.cogwheel.conduit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat

class MainActivity : FlutterActivity() {
    private lateinit var backgroundStreamingHandler: BackgroundStreamingHandler
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Modern edge-to-edge implementation for Android 15+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            window.decorView.setOnApplyWindowInsetsListener(null)
        }
        
        // Enable edge-to-edge display (backwards compatible)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize background streaming handler
        backgroundStreamingHandler = BackgroundStreamingHandler(this)
        backgroundStreamingHandler.setup(flutterEngine)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        if (::backgroundStreamingHandler.isInitialized) {
            backgroundStreamingHandler.cleanup()
        }
    }
}
