window.feedbin ?= {}

feedbin.hideQueue = []

feedbin.updateTitle = () ->
  title = "Feedbin"
  if feedbin.data && feedbin.data.show_unread_count && feedbin.data.viewMode != 'view_starred'
    count = $('[data-behavior~=all_unread]').first().find('.count').text() * 1
    if count == 0
      title = "Feedbin"
    else if count >= 1000
      title = "Feedbin (1,000+)"
    else
      title = "Feedbin (#{count})"

  docTitle = $('title')
  docTitle.text(title) unless docTitle.text() is title

feedbin.applyCounts = (useHideQueue) ->
  $('[data-behavior~=needs_count]').each (index, countContainer) =>
    group = $(countContainer).data('count-group')
    groupId = $(countContainer).data('count-group-id')

    collection = 'unread'
    if feedbin.data.viewMode == 'view_starred'
      collection = 'starred'

    counts = feedbin.Counts.get().counts[collection][group]
    countWas = $(countContainer).text() * 1
    count = 0

    if groupId
      if groupId of counts
        count = counts[groupId].length
    else
      count = counts.length
    $(countContainer).text(count)

    if count == 0
      $(countContainer).addClass('hide')
    else
      $(countContainer).removeClass('hide')

    if groupId
      container = $(countContainer).parents('li').first()
      if useHideQueue
        feedId = $(container).data('feed-id')
        if count == 0 && countWas > 0
          feedbin.hideQueue.push(feedId)
        if countWas == 0 && count > 0
          index = feedbin.hideQueue.indexOf(feedId)
          if index > -1
            feedbin.hideQueue.splice(index, 1);
          container.removeClass('zero-count')
      else
        container.removeClass('zero-count')
        if count == 0
          container.addClass('zero-count')

  feedbin.updateTitle()

jQuery ->
  new feedbin.CountsBehavior()

class feedbin.CountsBehavior
  constructor: ->
    feedbin.applyCounts(false)
    $(document).on('click', '[data-behavior~=change_view_mode]', @changeViewMode)
    $(document).on('click', '[data-behavior~=show_entry_content]', @showEntryContent)
    $(document).on('click', '[data-behavior~=show_entries]', @processHideQueue)
    $(document).on('ajax:beforeSend', '[data-behavior~=toggle_read]', @toggleRead)
    $(document).on('ajax:beforeSend', '[data-behavior~=toggle_starred]', @toggleStarred)

  changeViewMode: (event) =>
    feedbin.hideQueue = []
    element = $(event.currentTarget)
    $('[data-behavior~=change_view_mode]').removeClass('selected')
    element.addClass('selected')

    feedbin.data.viewMode = element.data('view-mode')

    $('body').removeClass('view_all view_unread view_starred');
    $('body').addClass(feedbin.data.viewMode);
    feedbin.applyCounts(false)

    if feedbin.openFirstItem
      $('[data-behavior~=feeds_target] li:visible').first().find('a')[0].click();
      feedbin.openFirstItem = false;

  showEntryContent: (event) =>
    container = $(event.currentTarget)
    entry = $(container).data('entry-info')

    feedbin.selectedEntry =
      id: entry.id
      feed_id: entry.feed_id
      published: entry.published
      container: container

    clearTimeout feedbin.recentlyReadTimer

    if !@isRead(entry.id)
      $.post $(container).data('mark-as-read-path')
      feedbin.Counts.get().removeEntry(entry.id, entry.feed_id, 'unread')
      @mark('read')
      feedbin.recentlyReadTimer = setTimeout ( ->
        $.post $(container).data('recently-read-path')
      ), 10000

  isRead: (entryId) ->
    feedbin.Counts.get().isRead(entryId)

  isStarred: (entryId) ->
    feedbin.Counts.get().isStarred(entryId)

  toggleRead: (event, xhr) =>
    if @isRead(feedbin.selectedEntry.id)
      feedbin.Counts.get().addEntry(feedbin.selectedEntry.id, feedbin.selectedEntry.feed_id, feedbin.selectedEntry.published, 'unread')
      @unmark('read')
    else
      feedbin.Counts.get().removeEntry(feedbin.selectedEntry.id, feedbin.selectedEntry.feed_id, 'unread')
      @mark('read')

  mark: (property) ->
    feedbin.applyCounts(true)
    $("[data-entry-id=#{feedbin.selectedEntry.id}]").addClass(property)

  unmark: (property) ->
    feedbin.applyCounts(true)
    $("[data-entry-id=#{feedbin.selectedEntry.id}]").removeClass(property)

  toggleStarred: (event, xhr) =>
    if @isStarred(feedbin.selectedEntry.id)
      feedbin.Counts.get().removeEntry(feedbin.selectedEntry.id, feedbin.selectedEntry.feed_id, 'starred')
      @unmark('starred')
    else
      feedbin.Counts.get().addEntry(feedbin.selectedEntry.id, feedbin.selectedEntry.feed_id, feedbin.selectedEntry.published, 'starred')
      @mark('starred')

  processHideQueue: =>
    $.each feedbin.hideQueue, (index, feed_id) ->
      if feed_id != undefined
        item = $("[data-feed-id=#{feed_id}]", '.feeds')
        $(item).addClass('zero-count')
    feedbin.hideQueue = []
    return
