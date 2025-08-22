// Make picture elements respond to MkDocs Material theme toggle
document.addEventListener('DOMContentLoaded', function() {
  function updatePictureElements() {
    let scheme = document.documentElement.getAttribute('data-md-color-scheme');
    
    // Check which palette input is actually checked
    const checkedPalette = document.querySelector('input[data-md-color-scheme]:checked');
    if (checkedPalette) {
      const paletteId = checkedPalette.id;
      console.log('Checked palette ID:', paletteId);
      
      // Based on your MkDocs config: palette 0=auto, palette 1=light, palette 2=dark
      if (paletteId === '__palette_0') {
        scheme = 'auto';
      } else if (paletteId === '__palette_1') {
        scheme = 'light';
      } else if (paletteId === '__palette_2') {
        scheme = 'dark';
      }
    }
    
    if (!scheme) {
      scheme = document.body.getAttribute('data-md-color-scheme') || 'default';
    }
    
    console.log('All data-md-color-scheme elements:', document.querySelectorAll('[data-md-color-scheme]'));
    console.log('HTML element data-md-color-scheme:', document.documentElement.getAttribute('data-md-color-scheme'));
    console.log('Body element data-md-color-scheme:', document.body.getAttribute('data-md-color-scheme'));
    
    // Check all palette inputs to see their values
    const paletteInputs = document.querySelectorAll('input[data-md-color-scheme]');
    paletteInputs.forEach((input, i) => {
      console.log(`Palette ${i}: scheme=${input.getAttribute('data-md-color-scheme')}, checked=${input.checked}`);
    });
    
    const pictures = document.querySelectorAll('picture');
    
    console.log('Theme scheme:', scheme);
    
    pictures.forEach(picture => {
      const darkSource = picture.querySelector('source[media*="dark"]');
      const lightSource = picture.querySelector('source[media*="light"]');
      const img = picture.querySelector('img');
      
      if (darkSource && lightSource && img) {
        const darkSrc = darkSource.getAttribute('srcset');
        const lightSrc = lightSource.getAttribute('srcset');
        
        console.log('Dark src:', darkSrc);
        console.log('Light src:', lightSrc);
        
        let useDark = false;
        
        if (scheme === 'dark' || scheme === 'slate') {
          useDark = true;
        } else if (scheme === 'light') {
          useDark = false;
        } else if (scheme === 'auto') {
          // Automatic mode - check system preference
          useDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        } else {
          // Fallback for 'default' - assume dark since that's your site default
          useDark = true;
        }
        
        console.log('Current img.src before change:', img.src);
        console.log('Should use dark?', useDark);
        console.log('Dark src path:', darkSrc);
        console.log('Light src path:', lightSrc);
        
        // Force browser to update by recreating the image element
        const newImg = document.createElement('img');
        newImg.alt = img.alt;
        newImg.width = img.width;
        newImg.className = img.className;
        
        if (useDark) {
          newImg.src = darkSrc;
          console.log('RECREATING WITH DARK IMAGE:', darkSrc);
        } else {
          newImg.src = lightSrc;
          console.log('RECREATING WITH LIGHT IMAGE:', lightSrc);
        }
        
        img.parentNode.replaceChild(newImg, img);
        
        console.log('Final img.src after change:', img.src);
        console.log('---');
      }
    });
  }
  
  // Update on initial load
  updatePictureElements();
  
  // Watch for theme changes via MutationObserver
  const observer = new MutationObserver(updatePictureElements);
  observer.observe(document.documentElement, {
    attributes: true,
    attributeFilter: ['data-md-color-scheme']
  });
  
  // Also listen for clicks on theme toggle buttons
  document.addEventListener('click', function(e) {
    if (e.target.closest('[data-md-component="palette"]')) {
      setTimeout(updatePictureElements, 100); // Small delay to let theme change
    }
  });
});