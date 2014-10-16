$(document).ready(function() {
  player_hit()
  player_stand()
  dealer_flip()
  dealer_hit()
});

function player_hit() {
  $(document).on('click', '#hit_form input', function() {
    $.ajax({
      url: '/game/player/hit',
      type: 'POST'
    })
      .done(function(msg) {
        $('#game').replaceWith(msg);
      });
  return false;
  });
}

function player_stand() {
  $(document).on('click', '#stand_form input', function() {
    $.ajax({
      url: '/game/player/stand',
      type: 'POST'
    })
      .done(function(msg) {
        $('#game').replaceWith(msg);
      });
  return false;
  });
}

function dealer_flip() {
  $(document).on('click', '#flip_form input', function() {
    $.ajax({
      url: '/game/dealer/flip',
      type: 'POST'
    })
      .done(function(msg) {
        $('#game').replaceWith(msg);
      });
  return false;
  });
}

function dealer_hit() {
  $(document).on('click', '#dealer_hit_form input', function() {
    $.ajax({
      url: '/game/dealer/hit',
      type: 'POST'
    })
      .done(function(msg) {
        $('#game').replaceWith(msg);
      });
  return false;
  });
}